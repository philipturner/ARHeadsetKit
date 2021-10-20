//
//  MainRenderer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import MetalKit
import ARKit

open class MainRenderer {
    public unowned let coordinator: AppCoordinator
    var session: ARSession
    var view: MTKView
    
    public internal(set) var device: MTLDevice
    public internal(set) var commandQueue: MTLCommandQueue
    var library: MTLLibrary
    @usableFromInline var defaultFragmentFunction: MTLFunction!
    
    /**
     Use this to express that triple-buffering is being used instead of hard-coding the number of 3.
     
     Multiply this constant by the size of a data structure that is filled by the CPU each frame.
     ```swift
     let bufferSize = MainRenderer.numRenderBuffers * MemoryLayout<UInt32>.stride
     ```
     */
    public static let numRenderBuffers = 3
    /// Use this to index into an array of uniforms for triple-buffering.
    public internal(set) var renderIndex: Int = -1
    var renderSemaphore = DispatchSemaphore(value: numRenderBuffers)
    
    /// Whether the device's GPU can run optimized shaders that use vertex amplification.
    public internal(set) var usingVertexAmplification: Bool
    /// Whether the device can use scene reconstruction and hand reconstruction.
    public internal(set) var usingLiDAR: Bool
    
    /**
     Whether the user's finger is touching the screen this frame.
     
     This does not register touches in the settings panel.
     */
    public internal(set) var touchingScreen = false
    /**
     Whether the user's finger touched the screen last frame.
     
     This is false if ``MainRenderer/touchingScreen`` is false.
     */
    public internal(set) var longPressingScreen = false
    /**
     Whether the user's finger just started touching the screen this frame.
     
     This does not register touches in the settings panel.
     */
    @inlinable @inline(__always)
    public var shortTappingScreen: Bool { touchingScreen && !longPressingScreen }
     
    var timeSinceLastTouch: Int = 200_000_000
    var timeSinceCurrentTouch: Int = 100_000_000
    var lastTouchDirectionWasSwitch = false
  
    /// Whether headset mode is active.
    public internal(set) var usingHeadsetMode = false
    /// Whether the user's rendered position is different from their real-world position.
    public internal(set) var usingFlyingMode = false
    var alreadyStartedUsingFlyingMode = false
    var flyingDirectionIsForward = true
    
    var allowingSceneReconstruction = true
    var allowingHandReconstruction = true
    
    /// The color converted from color temperature, then multiplied by ambient intensity.
    public internal(set) var ambientLightColor: simd_half3!
    /// Each component equals the ambient intensity.
    public internal(set) var directionalLightColor: simd_half3!
    /// Always [0, 1, 0], meaning the light source is directly upward.
    public internal(set) var lightDirection = simd_half3(simd_float3(0, 1, 0))
    
    @inlinable @inline(__always)
    var cameraMeasurements: CameraMeasurements { userSettings.cameraMeasurements }
    
    /**
     Render any ``ARInterfaceElement`` that is centered around the user at this distance from the user's head.
     
     This may be overriden. The default value is 0.7.
     */
    open class var interfaceDepth: Float { 0.7 }
    @usableFromInline var interfaceScale: Float = .nan
    @usableFromInline var interfaceScaleChanged = false
    /// Use this to guide interactions with an AR interface or other virtual objects.
    public internal(set) var interactionRay: RayTracing.Ray?
    
    var colorTextureY: MTLTexture!
    var colorTextureCbCr: MTLTexture!
    var sceneDepthTexture: MTLTexture!
    var segmentationTexture: MTLTexture!
    var textureCache: CVMetalTextureCache
    
    var msaaTexture: MTLTexture
    var depthStencilTexture: MTLTexture
    var depthStencilState: MTLDepthStencilState
    
    @usableFromInline var userSettings: UserSettings!
    var handRenderer: HandRenderer!
    var handRenderer2D: HandRenderer2D!
    var customRenderer: CustomRenderer?
    
    var sceneRenderer: SceneRenderer!
    var sceneRenderer2D: SceneRenderer2D!
    /**
     Send an ``ARInterfaceElement`` to this every frame to render it.
     
     Call one of the following methods of ``InterfaceRenderer`` to render an `ARInterfaceElement`:
     - ``InterfaceRenderer/render(element:)``
     - ``InterfaceRenderer/render(elements:)``
     */
    public var interfaceRenderer: InterfaceRenderer!
    /**
     Send an ``ARObject`` to this every frame to render it
     
     Call one of the following methods of ``CentralRenderer`` to render an `ARObject`:
     
     One object:
     - ``CentralRenderer/render(object:)``
     - ``CentralRenderer/render(object:desiredLOD:)``
     - ``CentralRenderer/render(object:desiredLOD:userDistanceEstimate:)``
     
     Multiple objects at once:
     - ``CentralRenderer/render(objects:)``
     - ``CentralRenderer/render(objects:desiredLOD:)``
     - ``CentralRenderer/render(objectGroup:desiredLOD:)``
     */
    public internal(set) var centralRenderer: CentralRenderer!
    
    var timeSinceSettingsOpenAnimationStart = Int.min
    @usableFromInline var shouldRenderToDisplay = true
    
    @nonobjc
    public init(session: ARSession, view: MTKView, coordinator: AppCoordinator) {
        self.session = session
        self.view = view
        self.coordinator = coordinator
        
        device = view.device!
        commandQueue = device.makeCommandQueue()!
        commandQueue.optLabel = "Command Queue"
        
        // Not using vertex amplification on A13 GPUs because they don't support
        // MSAA with layered rendering. Vertex amplification can still be used
        // with viewports instead of layers, but viewports don't work with VRR and
        // have significantly worse rendering performance than using layers.
        
        usingVertexAmplification = device.supportsFamily(.apple7)
        usingLiDAR = !coordinator.disablingLiDAR && ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh)
        
        textureCache = CVMetalTextureCache?(nil,    [kCVMetalTextureCacheMaximumTextureAgeKey : 1e-5],
                                            device, [kCVMetalTextureUsage : MTLTextureUsage.shaderRead.rawValue])!
        
        
        
        let textureDescriptor = MTLTextureDescriptor()
        let bounds = UIScreen.main.nativeBounds
        textureDescriptor.width  = Int(bounds.height)
        textureDescriptor.height = Int(bounds.width)
        
        textureDescriptor.usage = .renderTarget
        textureDescriptor.textureType = .type2DMultisample
        textureDescriptor.storageMode = .memoryless
        textureDescriptor.sampleCount = 4
        
        textureDescriptor.pixelFormat = view.colorPixelFormat
        msaaTexture = device.makeTexture(descriptor: textureDescriptor)!
        msaaTexture.optLabel = "MSAA Texture"
        
        textureDescriptor.pixelFormat = .depth32Float_stencil8
        depthStencilTexture = device.makeTexture(descriptor: textureDescriptor)!
        depthStencilTexture.optLabel = "Depth-Stencil Texture"
        
        // Convential projection transforms map the vast majority of depth values
        // to the range (0.99, 1.00), drastically lowering depth precision for the
        // majority of any rendered scene and making z-fighting happen in some situations
        // situations just because an object is far away. This problem is often mitigated
        // by fine-tuning the near and far planes of a projection matrix, reducing
        // the dynamic range of the near and far clip planes.
        //
        // However, there is a more correct approach that allows extremely close and far
        // clip planes by undoing the loss in depth precision. Transforming depths by
        // subtracting them from one means the majority of depths fall in (0.00, 0.01).
        // When using a floating-point number instead of a normalized integer to store depth,
        // the high dynamic range of floating-point numbers means depths have much greater
        // precision when closer to zero.
        //
        // This solution is implemented by flipping the near and far planes in
        // the projection matrix. It also requires changing the depth compare mode
        // from "less" to "greater" and vice versa.
        //
        // NOTE: This approach only improves precision when using floating-point
        // depth formats. It does not affect precision of normalized integer depth formats.
        //
        // For more information on reversing z-buffers, see this:
        // https://developer.nvidia.com/content/depth-precision-visualized
        
        let depthStencilDescriptor = MTLDepthStencilDescriptor()
        depthStencilDescriptor.depthCompareFunction = .greater
        depthStencilDescriptor.isDepthWriteEnabled = true
        depthStencilDescriptor.optLabel = "Render Depth-Stencil State"
        depthStencilState = device.makeDepthStencilState(descriptor: depthStencilDescriptor)!
        
        
        
        library = try! device.makeDefaultLibrary(bundle: .safeModule)
        defaultFragmentFunction = library.makeFunction(name: "interfaceSurfaceFragmentShader")!
        
        let initializationSemaphore = DispatchSemaphore(value: 0)
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            if usingLiDAR {
                sceneRenderer = SceneRenderer(renderer: self, library: library)
            }
            
            sceneRenderer2D = SceneRenderer2D(renderer: self, library: library)
            
            initializationSemaphore.signal()
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            userSettings    = UserSettings   (renderer: self, library: library)
            centralRenderer = CentralRenderer(renderer: self, library: library)
            
            if usingLiDAR {
                handRenderer = HandRenderer(renderer: self, library: library)
            }
            
            handRenderer2D = HandRenderer2D(renderer: self, library: library)
            
            let appLibrary = try? device.makeDefaultLibrary(bundle: .main)
            customRenderer = makeCustomRenderer(self, appLibrary)

            initializationSemaphore.signal()
        }
        
        interfaceRenderer = InterfaceRenderer(renderer: self, library: library)
        
        initializationSemaphore.wait()
        initializationSemaphore.wait()
    }
    
    deinit {
        customRenderer = nil
        
        handRenderer2D = nil
        handRenderer = nil
        sceneRenderer = nil
        
        interfaceRenderer = nil
        userSettings = nil
    }
    
    public typealias CustomRendererInitializer = (MainRenderer, MTLLibrary?) -> CustomRenderer?
    
    open var makeCustomRenderer: CustomRendererInitializer {
        { _, _ in nil }
    }
}



public protocol DelegateRenderer {
    @inlinable var renderer: MainRenderer { get }
}

public extension DelegateRenderer {
    @inlinable var device: MTLDevice { renderer.device }
    @inlinable var renderIndex: Int { renderer.renderIndex }
    @inlinable var usingVertexAmplification: Bool { renderer.usingVertexAmplification }
    @inlinable var usingLiDAR: Bool { renderer.usingLiDAR }
    
    @inlinable var shouldRenderToDisplay: Bool { renderer.shouldRenderToDisplay }
    @inlinable var usingHeadsetMode: Bool { renderer.usingHeadsetMode }
    @inlinable var usingFlyingMode: Bool { renderer.usingFlyingMode }
    
    /// The user-defined relative size of interface elements.
    @inlinable var interfaceScale: Float { renderer.interfaceScale }
    @inlinable var interfaceScaleChanged: Bool { renderer.interfaceScaleChanged }
    @inlinable var interfaceCenter: simd_float3 { renderer.cameraMeasurements.interfaceCenter }
    
    @inlinable var leftEyePosition: simd_float3 { renderer.cameraMeasurements.leftEyePosition }
    @inlinable var rightEyePosition: simd_float3 { renderer.cameraMeasurements.rightEyePosition }
    @inlinable var handheldEyePosition: simd_float3 { renderer.cameraMeasurements.handheldEyePosition }
    
    @inlinable var ambientLightColor: simd_half3 { renderer.ambientLightColor }
    @inlinable var directionalLightColor: simd_half3 { renderer.directionalLightColor }
    @inlinable var lightDirection: simd_half3 { renderer.lightDirection }
    
    internal var colorTextureY: MTLTexture! { renderer.colorTextureY }
    internal var colorTextureCbCr: MTLTexture! { renderer.colorTextureCbCr }
    internal var sceneDepthTexture: MTLTexture! { renderer.sceneDepthTexture }
    internal var segmentationTexture: MTLTexture! { renderer.segmentationTexture }
    
    @inlinable var interfaceRenderer: InterfaceRenderer { renderer.interfaceRenderer }
    @inlinable var centralRenderer: CentralRenderer { renderer.centralRenderer }
}

public extension DelegateRenderer {
    @inlinable var imageResolution: CGSize { renderer.cameraMeasurements.imageResolution }
    
    @inlinable var cameraToWorldTransform: simd_float4x4 { renderer.cameraMeasurements.cameraToWorldTransform }
    @inlinable var worldToCameraTransform: simd_float4x4 { renderer.cameraMeasurements.worldToCameraTransform }
    @inlinable var flyingPerspectiveToWorldTransform: simd_float4x4 { renderer.cameraMeasurements.flyingPerspectiveToWorldTransform }
    @inlinable var worldToFlyingPerspectiveTransform: simd_float4x4 { renderer.cameraMeasurements.worldToFlyingPerspectiveTransform }
    
    @inlinable var worldToScreenClipTransform: simd_float4x4 { renderer.cameraMeasurements.worldToScreenClipTransform }
    @inlinable var worldToHeadsetModeCullTransform: simd_float4x4 { renderer.cameraMeasurements.worldToHeadsetModeCullTransform }
    @inlinable var worldToLeftClipTransform: simd_float4x4 { renderer.cameraMeasurements.worldToLeftClipTransform }
    @inlinable var worldToRightClipTransform: simd_float4x4 { renderer.cameraMeasurements.worldToRightClipTransform }
    
    @inlinable var cameraSpaceLeftEyePosition: simd_float3 { renderer.cameraMeasurements.cameraSpaceLeftEyePosition }
    @inlinable var cameraSpaceRightEyePosition: simd_float3 { renderer.cameraMeasurements.cameraSpaceRightEyePosition }
    @inlinable var cameraSpaceHeadsetModeCullOrigin: simd_float3 { renderer.cameraMeasurements.cameraSpaceHeadsetModeCullOrigin }
    
    @inlinable var cameraToLeftClipTransform: simd_float4x4 { renderer.cameraMeasurements.cameraToLeftClipTransform }
    @inlinable var cameraToRightClipTransform: simd_float4x4 { renderer.cameraMeasurements.cameraToRightClipTransform }
    @inlinable var cameraToHeadsetModeCullTransform: simd_float4x4 { renderer.cameraMeasurements.cameraToHeadsetModeCullTransform }
}
#endif

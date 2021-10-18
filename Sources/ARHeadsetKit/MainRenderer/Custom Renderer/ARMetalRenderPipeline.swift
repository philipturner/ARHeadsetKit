//
//  ARMetalRenderPipeline.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 10/3/21.
//

import Metal

public struct ARMetalRenderPipelineState {
    @usableFromInline var handheldPipelineState: MTLRenderPipelineState
    @usableFromInline var headsetPipelineState: MTLRenderPipelineState
    
    init(_ handheldPipelineState: MTLRenderPipelineState, _ headsetPipelineState: MTLRenderPipelineState) {
        self.handheldPipelineState = handheldPipelineState
        self.headsetPipelineState  = headsetPipelineState
    }
}

/// Tessellation and ray tracing are not supported.
public struct ARMetalRenderPipelineDescriptor {
    @usableFromInline var renderer: MainRenderer
    @usableFromInline var descriptor: MTLRenderPipelineDescriptor
    @usableFromInline var label: String?
    
    /**
     The collection of vertex functions used by ARHeadsetKit to drive rendering. This must be set with custom shaders.
     */
    public var vertexFunction: ARMetalVertexFunction?
    
    /**
     The fragment function used by ARHeadsetKit to drive rendering. This does not need to be set with a custom shader.
     
     By default, this is set to a basic Blinn-Phong fragment function.
     */
    public var fragmentFunction: ARMetalFragmentFunction
    
    /// Resets ``fragmentFunction`` to the default.
    @inlinable @inline(__always)
    public mutating func resetFragmentFunction() {
        fragmentFunction = ARMetalFragmentFunction(renderer.defaultFragmentFunction)
    }
    
    public init(renderer: MainRenderer) {
        self.renderer = renderer
        
        descriptor = MTLRenderPipelineDescriptor()
        descriptor.sampleCount = 4
        
        descriptor.depthAttachmentPixelFormat = .depth32Float_stencil8
        descriptor.stencilAttachmentPixelFormat = .depth32Float_stencil8
        descriptor.inputPrimitiveTopology = .triangle
        
        fragmentFunction = ARMetalFragmentFunction(renderer.defaultFragmentFunction)
    }
    
    /// This label will disappear at runtime.
    @inlinable @inline(__always)
    public var optLabel: String! {
        get { debugLabelReturn(nil) { label } }
        set { debugLabel { label = newValue } }
    }
    
    /// See [`vertexDescriptor`](https://developer.apple.com/documentation/metal/mtlrenderpipelinedescriptor/1514681-vertexdescriptor).
    @inlinable @inline(__always)
    public var vertexDescriptor: MTLVertexDescriptor? {
        get { descriptor.vertexDescriptor }
        set { descriptor.vertexDescriptor = newValue }
    }
    
    /// See [`makeRenderPipelineState(descriptor:)`](https://developer.apple.com/documentation/metal/mtldevice/1433369-makerenderpipelinestate).
    @inlinable @inline(__always)
    public func makeRenderPipelineState() throws -> ARMetalRenderPipelineState {
        descriptor.fragmentFunction = fragmentFunction.fragmentFunction
        return try makeRenderPipelineState_noFragment()
    }
    
    @usableFromInline
    func makeRenderPipelineState_noFragment() throws -> ARMetalRenderPipelineState {
        guard let vertexFunction = vertexFunction else {
            struct NilVertexFunctionError: Error { let description = "Vertex function was not set" }
            throw NilVertexFunctionError()
        }
        
        descriptor.maxVertexAmplificationCount = 1
        descriptor.colorAttachments[0].pixelFormat = .bgr10_xr
        descriptor.vertexFunction = vertexFunction.handheldFunction
        debugLabel { descriptor.label = label }
        
        let pipeline1 = try renderer.device.makeRenderPipelineState(descriptor: descriptor)
        
        if renderer.usingVertexAmplification { descriptor.maxVertexAmplificationCount = 2 }
        descriptor.colorAttachments[0].pixelFormat = .rg11b10Float
        descriptor.vertexFunction = vertexFunction.headsetFunction
        debugLabel { descriptor.label = label?.appending(" (Headset Mode)") }
        
        let pipeline2 = try renderer.device.makeRenderPipelineState(descriptor: descriptor)
        
        return ARMetalRenderPipelineState(pipeline1, pipeline2)
    }
}

public extension MTLDevice {
    /// Pass this into the ``ARMetalRenderCommandEncoder`` to use custom shaders to render.
    @inlinable @inline(__always)
    func makeARRenderPipelineState(descriptor: ARMetalRenderPipelineDescriptor) throws -> ARMetalRenderPipelineState {
        try descriptor.makeRenderPipelineState()
    }
}



public struct ARMetalVertexFunction {
    @usableFromInline var handheldFunction: MTLFunction
    @usableFromInline var headsetFunction: MTLFunction
    
    @inlinable @inline(__always)
    init(_ handheldFunction: MTLFunction, _ headsetFunction: MTLFunction) {
        self.handheldFunction = handheldFunction
        self.headsetFunction = headsetFunction
    }
}

public struct ARMetalFragmentFunction {
    @usableFromInline var fragmentFunction: MTLFunction
    
    @inlinable @inline(__always)
    init(_ fragmentFunction: MTLFunction) {
        self.fragmentFunction = fragmentFunction
    }
}

public extension MTLLibrary {
    /**
     Create vertex shaders for an ARMetalRenderPipeline.
     
     - Parameters:
        - rendererName: The renderer the function belongs to. Must start with a lower-case letter
        - objectName: The object the function renders. Must start with an upper-case letter. The default is "Vertex".
     
     Vertex shaders in ARHeadsetKit must use a specific naming convention. A word (or camel-cased set of words) identifies the custom renderer, called the "renderer name". Another similarly formatted word is called the "object name". Vertex shaders names end with "Transform", and must not contain the word "shader".
     
     There are three shaders per pipeline, each of which calls a common C++ template function. As much code as possible is shared among shaders through the template.
        - The first shader runs when headset mode is disabled.
        - The second shader runs when headest mode is active, and vertex amplification can be used to optimize shader speed. This only runs on devices with at least the `.apple7` GPU family.
        - The third shader runs when headset mode is active, and vertex amplification cannot be used. This only runs on devices with the `.apple6` GPU family or earlier.
     
     Shader names are constructed like this:
     - Shared template function: \<renderer name> + \<object name> + "TransformCommon"
     - First shader: \<renderer name> + \<object name> + "Transform"
     - Second shader: \<renderer name> + "VR" + \<object name> + "Transform"
     - Third shader: \<renderer name> + "VR" + \<object name> + "Transform2"
     
     In the example below, the renderer name is "pendulum" and the object name is "Rectangle".
     - The shared template function's name is "pendulumRectangleTransformCommon".
     - The first shader's name is "pendulumRectangleTransform".
     - The second shader's name "pendulumVRRectangleTransform".
     - The third shader's name is "pendulumVRRectangleTransform2".
     */
    func makeARVertexFunction(rendererName: String, objectName: String = "Vertex") -> ARMetalVertexFunction {
        assert(!rendererName.first!.isUppercase)
        assert(objectName.first!.isUppercase)
        
        let name1 = rendererName + objectName + "Transform"
        let function1 = makeFunction(name: name1)!
        
        let suffix2 = device.supportsFamily(.apple7) ? "Transform" : "Transform2"
        let name2 = rendererName + "VR" + objectName + suffix2
        let function2 = makeFunction(name: name2)!
        
        return ARMetalVertexFunction(function1, function2)
    }
    
    /**
     Create a custom fragment shader.
     
     - Parameters:
        - name: The shader's name with "FragmentShader" removed. Must start with a lower-case letter.
     
     Fragment shaders in ARHeadsetKit must end with "FragmentShader". ARHeadsetKit's default fragment shader uses `ColorUtilities::getLightContribution()`, the fastest possible correct Blinn-Phong shading algorithm.
     
     - Warning: Do not attempt to use your own version of Blinn-Phong shading, as doing so will result in longer shader execution time.
     
     To use Blinn-Phong shading in a custom fragment shader, the output of the linked vertex shader must start with the following members, in the order they appear:
     - `float4 position [[position]]`: The required first component
     - `half3 eyeDirection_notNormalized`: A half-precision vector pointing from the pixel's location and toward the user's eye in world space.
     - `half3 normal_notNormalized`: A half-precision vector pointing away from the rendered object's surface, in world space.
     
     When passing these values out of a vertex function, the eye direction will not be normalized, but the normal will be. The process of interpolation de-normalizes the normal vector, unless every pixel within a triangle has the same normal. To correct this problem, the fragment shader re-normalizes the normal vector.
     */
    func makeARFragmentFunction(name: String) -> ARMetalFragmentFunction {
        assert(!name.first!.isUppercase)
        
        let name = name + "FragmentShader"
        let function = makeFunction(name: name)!
        
        return ARMetalFragmentFunction(function)
    }
}

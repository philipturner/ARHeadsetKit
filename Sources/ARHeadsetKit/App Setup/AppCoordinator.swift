//
//  AppCoordinator.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import MetalKit
import ARKit

open class AppCoordinator: NSObject, ObservableObject {
    public struct AppDescription {
        public var name: String
        public var summary: String?
        public var controlInterfaceColor: String
        public var tutorialExtension: String?
        public var mainActivity: String
        
        public init(name:                  String,
                    summary:               String? = nil,
                    controlInterfaceColor: String = "blue",
                    tutorialExtension:     String? = nil,
                    mainActivity:          String = "control this app")
        {
            self.name = name
            self.summary = summary
            self.controlInterfaceColor = controlInterfaceColor
            self.tutorialExtension = tutorialExtension
            self.mainActivity = mainActivity
        }
    }
    
    public internal(set) var appDescription: AppDescription
    
    @Published public var settingsIconIsHidden: Bool = false
    @Published var settingsAreShown: Bool = false
    @Published var settingsShouldBeAnimated: Bool = false
    @Published var showingAppTutorial: Bool = false
    
    @Published var appTutorialCheck: AppTutorialCheck = .init()
    
    var canCloseTutorial = true
    var shouldImmediatelyHideSettingsIcon = false
    
    @Published var renderingSettings: RenderingSettings!
    @Published var interactionSettings: InteractionSettings!
    @Published var lidarEnabledSettings: LiDAREnabledSettings!
    @Published var caseSize: LensDistortionCorrector.StoredSettings.CaseSize = .small
    
    var session: ARSession
    var view: MTKView
    var renderer: MainRenderer!
    
    var separatorView: UIView
    private var separatorGestureRecognizer: UILongPressGestureRecognizer
    private var gestureRecognizer: UILongPressGestureRecognizer
    
    var disablingLiDAR = false
    
    @nonobjc
    public init(appDescription: AppDescription) {
        self.appDescription = appDescription
        session = ARSession()
        
        let configuration = ARWorldTrackingConfiguration()
        
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
            configuration.sceneReconstruction = .mesh
            configuration.frameSemantics.insert(.sceneDepth)
            configuration.frameSemantics.insert(.personSegmentation)
            
            if configuration.videoFormat.imageResolution != CGSize(width: 1920, height: 1440) {
                if let desiredFormat = ARWorldTrackingConfiguration.supportedVideoFormats.first(where: {
                    $0.imageResolution == CGSize(width: 1920, height: 1440)
                }) {
                    configuration.videoFormat = desiredFormat
                } else {
                    disablingLiDAR = true
                }
            }
        } else {
            if ARWorldTrackingConfiguration.supportsFrameSemantics(.personSegmentation) {
                configuration.frameSemantics.insert(.personSegmentation)
            } else {
                // Likely using an A11 chip or older.
                fatalError("""
                    Need to account for this situation with some kind of warning. Tell the user \
                    their device is too old or incompatible.
                    """)
                // Option 2 (better): In "Info.plist", add the requirement of "Minimum A12 Performance"
            }
        }
        
        session.run(configuration)
        Self.purgeCameraGrainTexture(session: session)
        
        
        
        view = MTKView()
        
        let nativeBounds = UIScreen.main.nativeBounds
        view.drawableSize = .init(width: nativeBounds.height, height: nativeBounds.width)
        view.autoResizeDrawable = false
        
        let castedLayer = view.layer as! CAMetalLayer
        castedLayer.framebufferOnly = false
        castedLayer.allowsNextDrawableTimeout = false
        
        view.device = MTLCreateSystemDefaultDevice()!
        view.colorPixelFormat = .bgr10_xr
        
        
        
        func makeGestureRecognizer() -> UILongPressGestureRecognizer {
            let output = UILongPressGestureRecognizer()
            output.allowableMovement = .greatestFiniteMagnitude
            output.minimumPressDuration = 0
            return output
        }
        
        gestureRecognizer = makeGestureRecognizer()
        view.addGestureRecognizer(gestureRecognizer)
        
        separatorGestureRecognizer = makeGestureRecognizer()
        separatorView = HeadsetViewSeparator<Self>.separatorView
        separatorView.addGestureRecognizer(separatorGestureRecognizer)
        
        
        
        super.init()
        view.delegate = self
        renderer = makeMainRenderer(session, view, self)
        
        
        
        var storedSettings: UserSettings.StoredSettings {
            renderer.userSettings.storedSettings
        }
        
        renderingSettings = .init(storedSettings)
        interactionSettings = .init(storedSettings)
        lidarEnabledSettings = .init(storedSettings)
        
        caseSize = renderer.userSettings.lensDistortionCorrector.storedSettings.caseSize
        
        if storedSettings.isFirstAppLaunch {
            showingAppTutorial = true
            canCloseTutorial = false
        }
        
        initializeCustomSettings(from: storedSettings.customSettings)
    }
    
    deinit {
        renderer = nil
    }
    
    private static func purgeCameraGrainTexture(session: ARSession) {
        DispatchQueue.global(qos: .background).async {
            while true {
                usleep(5_000_000)
                
                if let frame = session.currentFrame,
                   let cameraGrainTexture = frame.cameraGrainTexture {
                    cameraGrainTexture.setPurgeableState(.empty)
                    return
                }
            }
        }
    }
    
    public typealias MainRendererInitializer = (ARSession, MTKView, AppCoordinator) -> MainRenderer
    
    /**
     Override this with the initializer for your subclass of ``MainRenderer``.
     
     ```swift
     override var makeMainRenderer: MainRendererInitializer { MyApp_MainRenderer.init }
     ```
     */
    open var makeMainRenderer: MainRendererInitializer { MainRenderer.init }
    
    /// Override this if you have settings that must persist across app launches.
    open func initializeCustomSettings(from storedSettings: [String : String]) { }
    
    /// Override this to update persistent settings every frame.
    open func modifyCustomSettings(customSettings: inout [String : String]) { }
}

extension AppCoordinator: MTKViewDelegate {
    
    /// Do not call this method.
    public func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) { }
    
    /// Do not call this method.
    public func draw(in view: MTKView) {
        assert(view === self.view)
        
        if !appTutorialCheck.check1 {
            if appTutorialCheck.check2 { appTutorialCheck.check2 = false }
            if appTutorialCheck.check3 { appTutorialCheck.check3 = false }
        }
        
        if gestureRecognizer.state != .possible || separatorGestureRecognizer.state != .possible {
            renderer.touchingScreen = true
            
            if interactionSettings.canHideSettingsIcon, !settingsIconIsHidden, !settingsAreShown {
                settingsIconIsHidden = true
            }
        } else {
            renderer.longPressingScreen = false
        }
        
        renderer.update()
        
        if renderer.touchingScreen {
            renderer.longPressingScreen = true
            renderer.touchingScreen = false
        }
    }
    
}
#endif

//
//  LensDistortionCorrector.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/10/21.
//

import Metal
import ARKit
import DeviceKit

final class LensDistortionCorrector: DelegateUserSettings {
    unowned let userSettings: UserSettings
    
    var usingThreadgroups: Bool
    var usingVRR: Bool
    
    var renderingCoordinationSemaphore = DispatchSemaphore(value: 0)
    var framebufferReferences: [MTLTexture] = []
    
    var showingRedColor = true
    var showingBlueColor = true
    
    var updatingIntermediateTexture = false
    var waitingOnInitialCameraMeasurements = true
    var timeSinceLastIntermediateTextureUpdate: Int = .min
    var intermediateTextureUpdateSemaphore = DispatchSemaphore(value: 0)
    
    var shouldUseCurrentPipeline = true
    var shouldCreateNewPipeline = false
    var justCreatedNewPipeline = false
    var updatingLensDistortionPipeline = false
    
    var savingSettings = false
    var shouldSaveSettings = false
    var updatedIntermediateTextureDuringTemporaryState = false
    
    enum MutabilityState {
        case permanent
        case temporary
    }
    
    private var protectedStoredSettings: StoredSettings!
    private var protectedOptimizedPipelineState: MTLComputePipelineState?
    
    private var _mutabilityState: MutabilityState = .permanent
    var mutabilityState: MutabilityState {
        get { _mutabilityState }
        set {
            guard _mutabilityState != newValue else {
                return
            }
            
            _mutabilityState = newValue
            
            switch newValue {
            case .permanent:
                if !protectedStoredSettings.viewportMatches(storedSettings) {
                    framebufferReferences.removeAll(keepingCapacity: true)
                }
                
                storedSettings = protectedStoredSettings
                pendingStoredSettings = protectedStoredSettings
                optimizedCorrectLensDistortionPipelineState = protectedOptimizedPipelineState
                
                if updatedIntermediateTextureDuringTemporaryState {
                    updatedIntermediateTextureDuringTemporaryState = false
                    updatingIntermediateTexture = true
                }
            case .temporary:
                protectedStoredSettings = storedSettings
                protectedOptimizedPipelineState = optimizedCorrectLensDistortionPipelineState
            }
        }
    }
    
    var storedSettings: StoredSettings
    var pendingStoredSettings: StoredSettings
    
    var screenDimensions: simd_long2
    var pixelsPerMeter: Double
    var clearFramebufferDispatchSize: MTLSize
    var viewSideLength: Int
    
    var viewCenterToMiddleDistance: Int!
    var viewCenterToBottomDistance: Int!
    var correctLensDistortionDispatchSize: MTLSize!
    
    var intermediateSideLength: Int!
    var intermediateTextureDimensions: simd_long2!
    var intermediateResolutionCompressionRatio: Float!
    
    enum UniformLayer: UInt16, MTLBufferLayer {
        case vrrMap
        
        static let bufferLabel = "User Settings Uniform Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .vrrMap: return capacity * MainRenderer.numRenderBuffers * MemoryLayout<UInt8>.stride
            }
        }
    }
    
    var uniformBuffer: MTLLayeredBuffer<UniformLayer>
    
    var vrrMapIndex = -1
    var vrrMap: MTLRasterizationRateMap!
    var previousVRRPartition: VRRFullPartition!
    var previousIntermediateSideLength: Int!
    
    var vrrMapOffset: Int { vrrMapIndex * uniformBuffer.capacity * MemoryLayout<UInt8>.stride }
    var lensDistortionUniformOffset: Int { renderIndex * MemoryLayout<LensDistortionUniforms>.stride }
    
    var headsetModeMSAATexture: MTLTexture!
    var headsetModeResolveTexture: MTLTexture!
    var headsetModeDepthStencilTexture: MTLTexture!
    
    var clearFramebufferPipelineState: MTLComputePipelineState
    var genericCorrectLensDistortionPipelineState: MTLComputePipelineState
    
    var optimizedCorrectLensDistortionPipelineState: MTLComputePipelineState?
    var newOptimizedCorrectLensDistortionPipelineState: MTLComputePipelineState?
    
    init(userSettings: UserSettings, library: MTLLibrary) {
        self.userSettings = userSettings
        let device = userSettings.device
        
        usingThreadgroups = device.supportsFamily(.apple4)
        usingVRR          = device.supportsFamily(.apple6)
        
        if userSettings.storedSettings.isFirstAppLaunch {
            shouldSaveSettings = true
        }
        
        storedSettings = Self.retrieveSettings() ?? .defaultSettings
        pendingStoredSettings = storedSettings
        
        let nativeBounds = UIScreen.main.nativeBounds
        screenDimensions = [Int(nativeBounds.height), Int(nativeBounds.width)]
        pixelsPerMeter = Double(screenDimensions.y) / userSettings.cameraMeasurements.screenSize.y
        
        clearFramebufferDispatchSize = [ (screenDimensions.x + 1) >> 1, (screenDimensions.y + 1) >> 1 ]
        viewSideLength = ~1 & (Int(round(storedSettings.viewportDiameter * pixelsPerMeter)) + 1)
        viewSideLength = min(2048, viewSideLength)
        
        
        
        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        computePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = usingThreadgroups
        
        computePipelineDescriptor.computeFunction = library.makeFunction(name: "clearFramebuffer")!
        computePipelineDescriptor.optLabel = "Clear Framebuffer Pipeline"
        clearFramebufferPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        computePipelineDescriptor.computeFunction = library.makeFunction(name: usingVRR
                                                                             ? "genericCorrectLensDistortion"
                                                                             : "correctLensDistortion_noVRR")!
        computePipelineDescriptor.optLabel = "Generic Correct Lens Distortion Pipeline"
        genericCorrectLensDistortionPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        
        
        uniformBuffer = device.makeLayeredBuffer(capacity: 32768, options: [.cpuCacheModeWriteCombined, .storageModeShared])
        
        updateIntermediateTexture()
        vrrMap?.copyParameterData(buffer: uniformBuffer, layer: .vrrMap, offset: vrrMapOffset)
    }
    
    deinit {
        while updatingLensDistortionPipeline {
            usleep(100)
        }
        
        while savingSettings {
            usleep(100)
        }
        
        if mutabilityState == .permanent, pendingStoredSettings != storedSettings {
            Self.saveSettings(pendingStoredSettings)
        }
    }
}

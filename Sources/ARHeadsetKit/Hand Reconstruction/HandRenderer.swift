//
//  HandRenderer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import simd

final class HandRenderer: DelegateRenderer {
    unowned let renderer: MainRenderer
    
    var preferredHandednessIsRight: Bool? = nil
    
    var didWaitOnSegmentationTextureSemaphore = true
    var didWaitOnColorTextureSemaphore = true
    var segmentationTextureSemaphore = DispatchSemaphore(value: 0)
    var colorTextureSemaphore = DispatchSemaphore(value: 0)
    
    var currentlyDetectingHand = false
    var pendingLocationReturn: (() -> Void)!
    
    var rayOriginDuringSample = simd_float3.zero
    var cameraToWorldTransformDuringSample = simd_float4x4(1)
    var worldToCameraTransformDuringSample = simd_float4x4(1)
    var pointProjectorDuringSample: PointProjector!
    
    var sampleCounter = 0
    var targetSamplingLevel: Int {
        get { handSamplingRateTracker.targetSamplingLevel }
        set { handSamplingRateTracker.targetSamplingLevel = newValue }
    }
    
    var rawPositions: [simd_float2]!
    var filteredPositions: [simd_float3]!
    var handCenter: simd_float3!
    var handDepth: Float!
    var detectionResults = HandDetectionResults()
    
    var projectedPositions2D: [simd_float2]!
    var projectedPositions3D: [simd_float3]!
    
    var handObjectGroup = ARObjectGroup(objects: [])
    var hand: Hand!
    var lastHandColor: simd_float3!
    var lastHand: Hand!
    var completedHand: Hand! {
        get { hand }
        set { hand = newValue }
    }
    
    var handRay: RayTracing.Ray!
    
    struct ComputeUniforms {
        var cameraToWorldTransform: simd_float4x4
        var handIsDetected: UInt8
        var segmentationTextureHasValues: Bool
        
        var handCenter: simd_float3
        var wristPosition: simd_float3
        var thumbJointPositions:  simd_float4x3
        var indexJointPositions:  simd_float4x3
        var middleJointPositions: simd_float4x3
        var ringJointPositions:   simd_float4x3
        var littleJointPositions: simd_float4x3
        
        var wristAndThumbColors: simd_half3x3
        var fingerKnuckleColors: simd_half4x3
        
        var positions: [simd_float3] {
            let positionArray = [thumbJointPositions, indexJointPositions, middleJointPositions,
                                 ringJointPositions, littleJointPositions].map{ $0.array }
            
            return positionArray.reduce([wristPosition], +).map {
                simd_float3($0.x, 1 - $0.y, $0.z)
            }
        }
    }
    
    var computeUniformBuffer: MTLBuffer
    
    var sampleJointDepths1PipelineState: MTLComputePipelineState
    var locateHandCenterPipelineState: MTLComputePipelineState
    var sampleJointDepths2PipelineState: MTLComputePipelineState
    
    var handColorTracker = HandColorTracker()
    var handParityTracker = HandParityTracker()
    var handSamplingRateTracker = HandSamplingRateTracker()
    
    var opticalFlowMeasurer: OpticalFlowMeasurer!
    var leftHandModelFitter:  HandModelFitter!
    var rightHandModelFitter: HandModelFitter!
    
    init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
        let device = renderer.device
        
        let computeUniformBufferSize = MemoryLayout<ComputeUniforms>.stride
        computeUniformBuffer = device.makeBuffer(length: computeUniformBufferSize, options: .storageModeShared)!
        computeUniformBuffer.optLabel = "Hand Renderer Compute Uniform Buffer"
        
        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        computePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        
        computePipelineDescriptor.computeFunction = library.makeFunction(name: "sampleJointDepths1")!
        computePipelineDescriptor.optLabel = "Hand Renderer Sample Joint Depths 1 Pipeline"
        sampleJointDepths1PipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        computePipelineDescriptor.computeFunction = library.makeFunction(name: "locateHandCenter")!
        computePipelineDescriptor.optLabel = "Hand Renderer Locate Hand Center Pipeline"
        locateHandCenterPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        computePipelineDescriptor.computeFunction = library.makeFunction(name: "sampleJointDepths2")!
        computePipelineDescriptor.optLabel = "Hand Renderer Sample Joint Depths 2 Pipeline"
        sampleJointDepths2PipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        opticalFlowMeasurer  = OpticalFlowMeasurer(renderer: renderer, library: library)
        leftHandModelFitter  = HandModelFitter(handRenderer: self, isRight: false)
        rightHandModelFitter = HandModelFitter(handRenderer: self, isRight: true)
    }
    
    deinit {
        opticalFlowMeasurer = nil
        
        while currentlyDetectingHand {
            usleep(100)
        }
    }
}

protocol DelegateHandRenderer { }
#endif

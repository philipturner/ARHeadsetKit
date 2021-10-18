//
//  HandRenderer2D.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/13/21.
//

import Metal
import ARKit
import Vision

final class HandRenderer2D: DelegateRenderer {
    unowned let renderer: MainRenderer
    
    typealias PointProjector = HandRenderer.PointProjector
    typealias HandDetectionResults = HandRenderer.HandDetectionResults
    
    var currentlyDetectingHand = false
    var pendingLocationReturn: (() -> Void)!
    
    var rayOriginDuringSample = simd_float3.zero
    var cameraToWorldTransformDuringSample = simd_float4x4(1)
    var pointProjectorDuringSample: PointProjector!
    
    var sampleCounter = 0
    var targetSamplingLevel: Int {
        get { handSamplingRateTracker.targetSamplingLevel }
        set { handSamplingRateTracker.targetSamplingLevel = newValue }
    }
    
    var rawPositions: [simd_float2]!
    var detectionResults: HandDetectionResults!
    var handRay: RayTracing.Ray!
    
    var handSamplingRateTracker = HandSamplingRateTracker()
    
    init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
        
        handSamplingRateTracker.targetSamplingLevel = 1
    }
    
    deinit {
        while currentlyDetectingHand {
            usleep(100)
        }
    }
}

extension HandRenderer2D {
    
    func locateHand(_ videoFrame: CVPixelBuffer) {
        let handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest.maximumHandCount = 1
        handPoseRequest.preferBackgroundProcessing = true
        
        let handler = VNImageRequestHandler(cvPixelBuffer: videoFrame)
        
        DispatchQueue.global(qos: .default).async { [self] in
            try! handler.perform([ handPoseRequest ])
            
            guard let observation = handPoseRequest.observations.first else {
                pendingLocationReturn = { [self] in
                    detectionResults = HandDetectionResults()
                    rawPositions = nil
                }
                
                currentlyDetectingHand = false
                return
            }
            
            var results = HandDetectionResults(observation: observation, aspectRatio: renderer.cameraMeasurements.aspectRatio)
            
            if results.optionStorage & 14 != 0 {
                results.isDetected = false
            }
            
            pendingLocationReturn = { [self] in
                detectionResults = results
                rawPositions = observation
            }
            
            currentlyDetectingHand = false
        }
    }
    
}


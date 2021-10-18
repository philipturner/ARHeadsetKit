//
//  HandRenderer2DExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/13/21.
//

import ARKit

extension HandRenderer2D {
    
    func updateResources(frame: ARFrame) {
        sampleCounter += 1
        
        if !currentlyDetectingHand {
            if pendingLocationReturn != nil {
                pendingLocationReturn!()
                pendingLocationReturn = nil
            }
            
            if let rawPositions = rawPositions {
                handSamplingRateTracker.registerSampleCompletion(didSucceed: true)
                
                let handPlaneDepth: Float = 0.5
                
                let jointWeights: [Float] = [0.375, 0.062, 0.063, 0.125, 0.125, 0.125, 0.125]
                let jointIndices: [Int] = [0, 1, 2, 5, 9, 13, 17]
                let averagePosition = (0..<7).reduce(simd_float2.zero){ fma(rawPositions[jointIndices[$1]], jointWeights[$1], $0) }
                
                let projectedPoint = pointProjectorDuringSample.findCameraSpaceXY(visionTexCoords: averagePosition) * handPlaneDepth
                let rayEnd = cameraToWorldTransformDuringSample * simd_float4(simd_float3(projectedPoint, -handPlaneDepth), 1)
                
                let rayDirection = normalize(simd_make_float3(rayEnd) - rayOriginDuringSample)
                handRay = .init(origin: rayOriginDuringSample, direction: rayDirection)
            } else {
                handSamplingRateTracker.registerSampleCompletion(didSucceed: false)
            }
            
            let retrievedSamplingRate = handSamplingRateTracker.samplingRate
            
            if sampleCounter >= retrievedSamplingRate {
                sampleCounter = 0
                
                let headPosition = simd_float4(renderer.cameraMeasurements.cameraSpaceHeadPosition, 1)
                rayOriginDuringSample = simd_make_float3(cameraToWorldTransform * headPosition)
                
                cameraToWorldTransformDuringSample = cameraToWorldTransform
                pointProjectorDuringSample = PointProjector(camera: frame.camera, imageResolution: imageResolution)
                
                currentlyDetectingHand = true
                locateHand(frame.capturedImage)
            }
        }
    }
    
}

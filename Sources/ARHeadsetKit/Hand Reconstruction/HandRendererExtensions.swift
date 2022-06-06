//
//  HandRendererExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/14/21.
//

#if !os(macOS)
import Metal
import ARKit

extension HandRenderer {
    
    func updateResources(frame: ARFrame) {
        sampleCounter += 1
        
        var storedSettings: UserSettings.StoredSettings { renderer.userSettings.storedSettings }
        
        if usingHeadsetMode, storedSettings.headsetHandedness != .none {
            preferredHandednessIsRight = storedSettings.headsetHandedness == .right
        } else {
            switch storedSettings.handheldHandedness {
            case .none:  preferredHandednessIsRight = nil
            case .left:  preferredHandednessIsRight = false
            case .right: preferredHandednessIsRight = true
            }
        }
        
        if !didWaitOnSegmentationTextureSemaphore { segmentationTextureSemaphore.wait() }
        if !didWaitOnColorTextureSemaphore { colorTextureSemaphore.wait() }
        
        opticalFlowMeasurer.updateResources()
        didWaitOnColorTextureSemaphore = false
        
        if !currentlyDetectingHand {
            if pendingLocationReturn != nil {
                pendingLocationReturn!()
                pendingLocationReturn = nil
                
                if let handCenter = handCenter, !handCenter.z.isNaN {
                    handDepth = handCenter.z
                    handColorTracker.append(detectionResults.color)
                    
                    registerDetection()
                } else {
                    handSamplingRateTracker.registerSampleCompletion(didSucceed: false)
                }
                
                if let handCenter = handCenter, let handDepth = handDepth {
                    let texCoords = simd_make_float2(handCenter)
                    let projectedPoint = pointProjectorDuringSample.findCameraSpaceXY(visionTexCoords: texCoords) * handDepth
                    let rayEnd = cameraToWorldTransformDuringSample * simd_float4(simd_float3(projectedPoint, -handDepth), 1)
                    
                    let rayDirection = normalize(simd_make_float3(rayEnd) - rayOriginDuringSample)
                    handRay = .init(origin: rayOriginDuringSample, direction: rayDirection)
                }
            }
            
            let retrievedSamplingRate = handSamplingRateTracker.samplingRate
            
            if sampleCounter >= retrievedSamplingRate {
                sampleCounter = 0
                handSamplingRateTracker.registerSampleStart(samplingRate: retrievedSamplingRate)
                
                let headPosition = simd_float4(renderer.cameraMeasurements.cameraSpaceHeadPosition, 1)
                rayOriginDuringSample = simd_make_float3(cameraToWorldTransform * headPosition)
                
                cameraToWorldTransformDuringSample = cameraToWorldTransform
                worldToCameraTransformDuringSample = worldToCameraTransform
                pointProjectorDuringSample = PointProjector(camera: frame.camera, imageResolution: imageResolution)
                
                if !didWaitOnSegmentationTextureSemaphore {
                    didWaitOnSegmentationTextureSemaphore = true
                    segmentationTextureSemaphore.wait()
                }
                
                didWaitOnColorTextureSemaphore = true
                colorTextureSemaphore.wait()
                
                currentlyDetectingHand = true
                locateHand(frame.capturedImage)
            }
        }
        
        centralRenderer.render(objectGroup: handObjectGroup, desiredLOD: 45)
        
        if let handColor = lastHandColor, var hand = lastHand {
            hand.mirrorSelf(handRenderer: self)
            let mirroredHandObjectGroup =
                ARObjectGroup(objects: hand.getWireframeObjects(color: handColor))
            centralRenderer.render(objectGroup: mirroredHandObjectGroup, desiredLOD: 45)
        }
    }
    
    func registerDetection() {
        var detectedLeftHand = false
        var detectedRightHand = false
        
        var shouldReconstructLeftHand: Bool
        var shouldReconstructRightHand: Bool
        
        if let preferredHandednessIsRight = preferredHandednessIsRight {
            shouldReconstructLeftHand = !preferredHandednessIsRight
            shouldReconstructRightHand = preferredHandednessIsRight
        } else {
            shouldReconstructLeftHand = true
            shouldReconstructRightHand = true
        }
        
        createProjectedPositions()
        
        if shouldReconstructLeftHand {
            if var leftRawReconstructedHand = reconstructHand(isRight: false) {
                leftRawReconstructedHand.transformPoints(transformDuringSample: cameraToWorldTransformDuringSample)
                leftHandModelFitter.inputHandData(worldSpaceHand: leftRawReconstructedHand)
                
                detectedLeftHand = true
            }
        }
        
        if shouldReconstructRightHand {
            if var rightRawReconstructedHand = reconstructHand(isRight: true) {
                rightRawReconstructedHand.transformPoints(transformDuringSample: cameraToWorldTransformDuringSample)
                rightHandModelFitter.inputHandData(worldSpaceHand: rightRawReconstructedHand)
                
                detectedRightHand = true
            }
        }
        
        handSamplingRateTracker.registerSampleCompletion(didSucceed: true)
        
        // Render hand
        
        let previouslyRenderedRight = handParityTracker.shouldRenderRight
        
        if detectedLeftHand, detectedRightHand {
            let leftHandEvidence = rightHandModelFitter.gatherEvidenceForNotThisHand()
            let rightHandEvidence = leftHandModelFitter.gatherEvidenceForNotThisHand()
            
            handParityTracker.append(leftHandEvidence: leftHandEvidence, rightHandEvidence: rightHandEvidence)
        }
        
        var shouldRenderLeft: Bool
        var shouldRenderRight: Bool
        
        if let preferredHandednessIsRight = preferredHandednessIsRight {
            if preferredHandednessIsRight {
                shouldRenderLeft = false
                shouldRenderRight = detectedRightHand
            } else {
                shouldRenderLeft = detectedLeftHand
                shouldRenderRight = false
            }
        } else {
            if handParityTracker.shouldRenderRight {
                shouldRenderLeft = false
                shouldRenderRight = detectedRightHand || !previouslyRenderedRight
            } else {
                shouldRenderLeft = detectedLeftHand || previouslyRenderedRight
                shouldRenderRight = false
            }
        }
        
        if shouldRenderRight {
            hand = rightHandModelFitter.getCompletedHand()
        } else if shouldRenderLeft {
            hand = leftHandModelFitter.getCompletedHand()
        }
        
        if hand != nil {
            let handColor = handColorTracker.color
            
            handObjectGroup = ARObjectGroup(objects: hand.getWireframeObjects(color: handColor))
            
            lastHandColor = handColor
            lastHand = hand
        }
    }
    
}
#endif

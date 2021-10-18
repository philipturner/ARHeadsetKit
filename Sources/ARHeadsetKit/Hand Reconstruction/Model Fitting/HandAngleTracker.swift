//
//  HandAngleTracker.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 5/23/21.
//

import simd

extension HandModelFitter {
    
    struct HandAngleTracker: DelegateHandModelFitter {
        unowned let handModelFitter: HandModelFitter
        
        var handRenderer: HandRenderer { handModelFitter.handRenderer }
        var cameraToWorldTransform: simd_float4x4 { handRenderer.cameraToWorldTransformDuringSample }
        var worldToCameraTransform: simd_float4x4 { handRenderer.worldToCameraTransformDuringSample }
        
        typealias HandDetectionResults = HandRenderer.HandDetectionResults
        var detectionResults: HandDetectionResults { handRenderer.detectionResults }
        var rawPositions: [simd_float2] { handRenderer.rawPositions }
        var filteredPositions: [simd_float3] { handRenderer.filteredPositions }
        
        var isRight: Bool { handModelFitter.isRight }
        var basis: HandBasis! { handModelFitter.basis }
        var averageLengths: HandLengths { handModelFitter.averageLengths }
        
        var knucklePositions: [simd_float3] = []
        var knuckleAngles: [Float] = .init(repeating: degreesToRadians(90), count: 4)
        var firstJointAngles: [Float] = .init(repeating: degreesToRadians(0), count: 4)
        
        init(handModelFitter: HandModelFitter) {
            self.handModelFitter = handModelFitter
        }
        
        mutating func append(_ worldSpaceHand: ReconstructedHand) {
            guard basis != nil, !detectionResults.isCloseToEdge else {
                return
            }
            
            @inline(__always)
            func makeCameraSpacePoint(_ point: simd_float3, _ w: Float) -> simd_float3 {
                simd_make_float3(worldToCameraTransform * simd_float4(point,  w))
            }
            
            let palmTangent   = makeCameraSpacePoint(basis.palmTangent,   0)
            let upDirection   = makeCameraSpacePoint(basis.upDirection,   0)
            let wristPosition = makeCameraSpacePoint(basis.wristPosition, 1)
            
            do {
                let dotProducts = dotAdd(wristPosition, palmTangent,
                                         wristPosition, wristPosition)
                
                if dotProducts[0] * dotProducts[0] < (0.18 * 0.18) * dotProducts[1] {
                    return
                }
            }
            
            let middleSegmentLength = averageLengths.getWristConnection(fingerID: 2)
            
            let middleKnuckle = fma(upDirection, middleSegmentLength, wristPosition)
            
            // Find angle cosines between palm segments
            
            let c_vector = simd_float3(
                averageLengths.getWristConnection(fingerID: 4),
                averageLengths.getWristConnection(fingerID: 3),
                averageLengths.getWristConnection(fingerID: 1)
            )
            
            let b_vector = simd_float3(
                averageLengths.getBetweenFingerConnection(endFingerID: 4),
                averageLengths.getBetweenFingerConnection(endFingerID: 3),
                averageLengths.getBetweenFingerConnection(endFingerID: 2)
            )
            
            let a_vector = simd_float3(c_vector.y, middleSegmentLength, middleSegmentLength)
            
            var denominators = a_vector * b_vector
            denominators += denominators
            
            let numerators = fma(a_vector, a_vector,
                             fma(b_vector, b_vector,
                                -c_vector * c_vector))
            
            let angleCosines = numerators / denominators
            let angleSines = sqrt(fma(-angleCosines, angleCosines, 1))
            
            // Find ring knuckle
            
            let middleToRingDirection = fma(upDirection, -angleCosines[1], -palmTangent * angleSines[1])
            let ringKnuckle = fma(middleToRingDirection, b_vector[1], middleKnuckle)
            
            // Find little knuckle
            
            let wristToRingDirection = normalize(ringKnuckle - wristPosition)
            
            let ringToLittleDirection = fma(wristToRingDirection, -angleCosines[0], middleToRingDirection * angleSines[0])
            let littleKnuckle = fma(ringToLittleDirection, b_vector[0], ringKnuckle)
            
            // Find index knuckle
            
            let middleToIndexDirection = fma(upDirection, -angleCosines[2], palmTangent * angleSines[2])
            let indexKnuckle = fma(middleToIndexDirection, b_vector[2], middleKnuckle)
            
            // Project raw Vision outputs
            
            var knucklePositions = simd_float4x3(
                indexKnuckle,
                middleKnuckle,
                ringKnuckle,
                littleKnuckle
            )
            
            var palmNormal = cross(upDirection, palmTangent)
            if isRight { palmNormal = -palmNormal }
            
            if !worldSpaceHand.components.contains(nil) {
                for i in 0..<4 {
                    let rangeStart = i << 2 + 5
                    let rangeEnd = rangeStart + 2
                    
                    let directions = [wristPosition] + handModelFitter.handRenderer.projectedPositions3D[rangeStart...rangeEnd]
                    
                    var projectedPoints: [simd_float3] = []
                    var planeTangent: simd_float3
                    
                    if i == 3 {
                        planeTangent = fma(upDirection,
                                           sin(degreesToRadians(7.5)),
                                           cos(degreesToRadians(7.5)) * palmTangent)
                    } else {
                        planeTangent = palmTangent
                    }
                    
                    let plane = RayTracing.Plane(point: knucklePositions[i], normal: planeTangent)
                    
                    var shouldEndIteration = false
                    
                    for direction in directions {
                        let projectedPoint = RayTracing.project(direction, onto: plane)
                        
                        guard projectedPoint.z <= -0.15, projectedPoint.z >= -0.75 else {
                            shouldEndIteration = true
                            break
                        }
                        
                        projectedPoints.append(projectedPoint)
                    }
                    
                    if shouldEndIteration || worldSpaceHand.components.contains(nil) { continue }
                    
                    
                    
                    var cachedProjectedPoint = projectedPoints[1]
                    var selectedUpDirection: simd_float3
                    
                    if i == 3 {
                        selectedUpDirection = fma(upDirection,
                                                  cos(degreesToRadians(7.5)),
                                                 -sin(degreesToRadians(7.5)) * palmTangent)
                    } else {
                        selectedUpDirection = upDirection
                    }
                    
                    @inline(__always)
                    func getElevationAngle(endIndex: Int) -> Float {
                        let currentProjectedPoint = projectedPoints[endIndex]
                        let delta = normalize(currentProjectedPoint - cachedProjectedPoint)
                        cachedProjectedPoint = currentProjectedPoint
                        
                        let palmNormalComponent  = dot(delta, palmNormal)
                        let upDirectionComponent = dot(delta, selectedUpDirection)
                        
                        return atan2(upDirectionComponent, palmNormalComponent)
                    }
                    
                    let knuckleAngle    = getElevationAngle(endIndex: 2)
                    let firstJointAngle = getElevationAngle(endIndex: 3) - knuckleAngle
                    
                    knuckleAngles[i] = knuckleAngle
                    firstJointAngles[i] = firstJointAngle
                }
            }
            
            let littleFingerAngle: Float = isRight ? degreesToRadians(10)  : degreesToRadians(-10)
            let ringFingerAngle: Float   = isRight ? degreesToRadians(7.5) : degreesToRadians(-7.5)
            
            let littleFingerRotation = simd_quatf(angle: littleFingerAngle, axis: upDirection)
            let ringFingerRotation   = simd_quatf(angle: ringFingerAngle,   axis: upDirection)
            
            var wristToLittleDelta = knucklePositions[3] - wristPosition
            let wristToRingDelta   = knucklePositions[2] - wristPosition
            
            let littleSegmentLength = c_vector[0]
            let maxLittleSegmentLength = 0.99 * c_vector[1]
            
            if littleSegmentLength > maxLittleSegmentLength {
                wristToLittleDelta *= maxLittleSegmentLength / littleSegmentLength
            }
            
            knucklePositions[3] = wristPosition + littleFingerRotation.act(wristToLittleDelta)
            knucklePositions[2] = wristPosition +   ringFingerRotation.act(wristToRingDelta)
            
            self.knucklePositions = (0..<4).map {
                let knucklePosition = cameraToWorldTransform * simd_float4(knucklePositions[$0], 1)
                return simd_make_float3(knucklePosition) - basis.wristPosition
            }
        }
    }
    
}

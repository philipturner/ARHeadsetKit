//
//  HandModelFitter.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 5/12/21.
//

#if !os(macOS)
import simd

final class HandModelFitter: DelegateHandRenderer {
    unowned let handRenderer: HandRenderer
    
    typealias ReconstructedHand = HandRenderer.ReconstructedHand
    typealias HandComponent = HandRenderer.HandComponent
    
    var isRight: Bool
    var basis: HandBasis! { orientationTracker.basis }
    
    var lengthHistory = HandLengthHistory()
    var averageLengths = HandLengths.defaultLengths
    var scale: Float = 1
    
    var orientationTracker: HandOrientationTracker!
    var angleTracker: HandAngleTracker!
    
    init(handRenderer: HandRenderer, isRight: Bool) {
        self.handRenderer = handRenderer
        self.isRight = isRight
        
        orientationTracker = HandOrientationTracker(handModelFitter: self)
        angleTracker = HandAngleTracker(handModelFitter: self)
    }
    
    func inputHandData(worldSpaceHand: ReconstructedHand) {
        if worldSpaceHand.directionsAreReliable {
            lengthHistory.append(worldSpaceHand)
            
            averageLengths = lengthHistory.averageLengths
            scale = averageLengths.scale
        }
        
        orientationTracker.append(worldSpaceHand)
        angleTracker.append(worldSpaceHand)
    }
    
    func gatherEvidenceForNotThisHand() -> Int {
        var output = 0
        
        for angle in angleTracker.knuckleAngles where angle > degreesToRadians(112) {
            output += 1
        }
        
        for angle in angleTracker.firstJointAngles where angle > degreesToRadians(22) {
            output += 1
        }
        
        return output
    }
    
}

protocol DelegateHandModelFitter { }

extension HandModelFitter {
    
    func getCompletedHand() -> Hand? {
        guard basis != nil, angleTracker.knucklePositions.count != 0 else {
            return nil
        }
        
        let thumbDirection1_notNormalized = basis.thumbJoint1
        var thumbDirection2 = basis.thumbDirection2
        
        let palmTangent = basis.palmTangent
        var palmNormal = cross(basis.upDirection, palmTangent)
        if isRight { palmNormal = -palmNormal }
        
        let thumbDirection3 = { () -> simd_float3 in
            let thumbDirection1 = normalize(thumbDirection1_notNormalized)
            
            let dotProduct1 = dot(thumbDirection1, palmNormal)
            guard dotProduct1 > 0 else {
                return thumbDirection2
            }
            
            let dotProduct2 = dot(thumbDirection2, palmNormal)
            var flatThumbDirection2 = fma(palmNormal, -dotProduct2, thumbDirection2)
            
            flatThumbDirection2 = normalize(thumbDirection2)
            let tangentComponent = dot(flatThumbDirection2, palmTangent)
            
            if dotProduct2 < 0 {
                thumbDirection2 = flatThumbDirection2
            }
            
            let thumbRotation = simd_quatf(from: thumbDirection1, to: thumbDirection2)
            var thumbDirection3 = thumbRotation.act(thumbDirection2)
            
            if dotProduct2 < 0 {
                thumbDirection3 = fma(palmNormal, -dot(thumbDirection3, palmNormal), thumbDirection3)
                
                thumbDirection3 = normalize(thumbDirection3)
            }
            
            let angleRangeStart: Float = 38
            let angleRangeEnd:   Float = -5
            
            if tangentComponent < sin(degreesToRadians(angleRangeEnd)) {
                return thumbDirection3
            }
            
            var t = asin(tangentComponent) - degreesToRadians(angleRangeStart)
            t *= 1 / degreesToRadians(angleRangeEnd - angleRangeStart)
            
            if dotProduct1 < 0.05 {
                t *= dotProduct1 * (1 / 0.05)
            }
            
            return simd_slerp(from: thumbDirection2, to: thumbDirection3, t: t)
        }()
        
        // Render thumb
        
        let wristPosition = basis.wristPosition
        let thumbJoint1 = wristPosition + thumbDirection1_notNormalized
        
        let thumbJoint2_length = averageLengths.getInsideFingerConnection(fingerID: 0, endJointID: 2)
        var thumbJoint3_length = averageLengths.getInsideFingerConnection(fingerID: 0, endJointID: 3)
        thumbJoint3_length = simd_clamp(thumbJoint3_length, 0.6 * thumbJoint2_length, thumbJoint2_length)
        
        let thumbJoint2 = fma(thumbDirection2, thumbJoint2_length, thumbJoint1)
        let thumbJoint3 = fma(thumbDirection3, thumbJoint3_length, thumbJoint2)
        
        var handCenter = fma(wristPosition, 0.375, thumbJoint1 * 0.125)
        
        // Render other fingers
        
        var fingerAngles = [simd_float3](unsafeUninitializedCount: 4)
        var components = [HandComponent](capacity: 6)
        
        components.append([wristPosition])
        components.append([thumbJoint1, thumbJoint2, thumbJoint3])
        
        for i in 0..<4 {
            var planeTangent = basis.palmTangent
            
            if i == 3 {
                planeTangent = fma(basis.upDirection,
                                   sin(degreesToRadians(7.5)),
                                   cos(degreesToRadians(7.5)) * planeTangent)
            }
            
            var knuckleAngle    = angleTracker.knuckleAngles   [min(i, 2)]
            var firstJointAngle = angleTracker.firstJointAngles[min(i, 2)]
            
            knuckleAngle = simd_clamp(knuckleAngle, degreesToRadians(-10), degreesToRadians(95))
            firstJointAngle = simd_clamp(firstJointAngle, -degreesToRadians(120), 0)
            var secondJointAngle = max(firstJointAngle, degreesToRadians(-185) - firstJointAngle)
            
            fingerAngles[i] = [knuckleAngle, firstJointAngle, secondJointAngle]
            
            if isRight {
                knuckleAngle = -knuckleAngle
                firstJointAngle = -firstJointAngle
                secondJointAngle = -secondJointAngle
            }
            
            let knuckleRotation     = simd_quatf(angle: knuckleAngle,     axis: planeTangent)
            let firstJointRotation  = simd_quatf(angle: firstJointAngle,  axis: planeTangent)
            let secondJointRotation = simd_quatf(angle: secondJointAngle, axis: planeTangent)
            
            let firstSegmentDirection  = knuckleRotation    .act(palmNormal)
            let secondSegmentDirection = firstJointRotation .act(firstSegmentDirection)
            let thirdSegmentDirection  = secondJointRotation.act(secondSegmentDirection)
            
            let fingerID = i + 1
            var segmentLengths = simd_make_float3_undef(0)
            
            for j in 0..<3 {
                segmentLengths[j] = averageLengths.getInsideFingerConnection(fingerID: fingerID,
                                                                             endJointID: j + 1)
            }
            
            segmentLengths[2] = simd_clamp(segmentLengths[2], 0.6 * segmentLengths[1], segmentLengths[1])
            
            let knucklePosition = basis.wristPosition + angleTracker.knucklePositions[i]
            
            let jointPosition1 = fma(firstSegmentDirection,  segmentLengths[0], knucklePosition)
            let jointPosition2 = fma(secondSegmentDirection, segmentLengths[1], jointPosition1)
            let jointPosition3 = fma(thirdSegmentDirection,  segmentLengths[2], jointPosition2)
            
            handCenter = fma(knucklePosition, 0.125, handCenter)
            
            components.append([knucklePosition, jointPosition1, jointPosition2, jointPosition3])
        }
        
        return Hand(components: components, fingerAngles: fingerAngles,
                    palmTangent: basis.palmTangent, upDirection: basis.upDirection,
                    palmNormal: palmNormal, center: handCenter)
    }
    
}
#endif

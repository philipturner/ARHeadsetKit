//
//  HandOrientationTracker.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 5/21/21.
//

#if !os(macOS)
import simd

extension HandModelFitter {
    
    struct HandBasis {
        var palmTangent: simd_float3
        var upDirection: simd_float3
        var wristPosition: simd_float3
        
        var thumbJoint1: simd_float3
        var thumbDirection2: simd_float3
    }
    
    struct HandOrientationTracker: DelegateHandModelFitter {
        unowned let handModelFitter: HandModelFitter
        var handLengths: HandLengths { handModelFitter.averageLengths }
        
        var lastPalmTangent: simd_float3!
        var lastUpDirection: simd_float3!
        var lastWristPosition: simd_float3!
        
        var lastThumbKnuckle: simd_float3!
        var lastFirstThumbJoint: simd_float3!
        var lastSecondThumbDirection: simd_float3!
        
        var lastValidThumbJoint: simd_float3!
        var lastValidThumbJointAngle: Float!
        var estimatedPalmTangent: simd_float3!
        
        var basis: HandBasis!
        var basisDidChange = false
        var objects: [ARObject] { basis?.objects ?? [] }
        
        init(handModelFitter: HandModelFitter) {
            self.handModelFitter = handModelFitter
        }
        
        mutating func append(_ input: ReconstructedHand) {
            inputHand(input)
            
            if basisDidChange {
                changeBasis()
            }
        }
        
        private mutating func inputHand(_ input: ReconstructedHand) {
            var directionsAreFound: Bool
            
            if input.directionsAreReliable {
                lastUpDirection = input.upDirection!
                directionsAreFound = true
                
                var nextPalmTangent = input.palmTangent!
                
                if input.palmTangentWasBackwards! {
                    if let lastPalmTangent = lastPalmTangent {
                        if dot(nextPalmTangent, lastPalmTangent) < -0.8 {
                            nextPalmTangent = -nextPalmTangent
                        }
                    }
                }
                
                lastPalmTangent = nextPalmTangent
                lastValidThumbJoint = nil
                estimatedPalmTangent = nextPalmTangent
            } else {
                directionsAreFound = false
            }
            
            // Guarantee wrist is found
            
            guard let wrist = input.components[0]?[0] else {
                basisDidChange = directionsAreFound
                return
            }
            
            basisDidChange = true
            lastWristPosition = wrist
            
            // Guarantee first thumb joint is found
            
            guard let thumbJoint1 = input.thumbJoint1 else {
                return
            }
            
            if let thumbJoint2 = input.components[1]?[2] {
                lastSecondThumbDirection = normalize(thumbJoint2 - thumbJoint1)
            }
            
            let nextThumbJoint1 = thumbJoint1 - wrist
            
            if let thumbKnuckle = input.thumbKnuckle {
                lastThumbKnuckle = thumbKnuckle - wrist
                lastFirstThumbJoint = nextThumbJoint1
            }
            
            // Guarantee model-space thumb joint can be found
            
            guard directionsAreFound || lastValidThumbJoint != nil else {
                return
            }
            
            guard let yAxis = lastUpDirection,
                  let zAxis = lastPalmTangent else {
                return
            }
            
            let thumbSegment1_direction = normalize(nextThumbJoint1)
            let xAxis = cross(yAxis, zAxis)
            
            let thumbJoint = dotAdd(thumbSegment1_direction, xAxis,
                                    thumbSegment1_direction, yAxis,
                                    thumbSegment1_direction, zAxis)
            
            if directionsAreFound {
                lastValidThumbJoint = thumbJoint
                lastValidThumbJointAngle = nil
            } else {
                let startThumbDirection = lastValidThumbJoint!
                var startAngle: Float
                
                if let lastValidThumbDirectionAngle = lastValidThumbJointAngle {
                    startAngle = lastValidThumbDirectionAngle
                } else {
                    startAngle = atan2(startThumbDirection.x, startThumbDirection.z)
                    lastValidThumbJointAngle = startAngle
                }
                
                let endAngle = atan2(thumbJoint.x, thumbJoint.z)
                let rotation = simd_quatf(angle: endAngle - startAngle, axis: yAxis)
                let newPalmTangent = rotation.act(zAxis)
                
                let thumbDirectionPerpendicularComponent = fma(-dot(yAxis, startThumbDirection), yAxis, startThumbDirection)
                
                if dot(newPalmTangent, thumbDirectionPerpendicularComponent) > 0 {
                    estimatedPalmTangent = newPalmTangent
                }
            }
        }
        
        private mutating func changeBasis() {
            guard let palmTangent = estimatedPalmTangent,
                  let upDirection = lastUpDirection,
                  let wristPosition = lastWristPosition,
                  
                  let thumbKnuckle = lastThumbKnuckle,
                  var thumbJoint1 = lastFirstThumbJoint,
                  let thumbDirection2 = lastSecondThumbDirection else {
                return
            }
            
            let wristSegment0_length = handLengths.getWristConnection(fingerID: 0)
            let wristSegment1_length = handLengths.getInsideFingerConnection(fingerID: 0, endJointID: 1)
            
            var thumbJoint0 = fma(dot(thumbKnuckle, upDirection), upDirection, palmTangent * dot(thumbKnuckle, palmTangent))
            
            thumbJoint0 *= wristSegment0_length * rsqrt(length_squared(thumbJoint0))
            
            thumbJoint1 = fma(wristSegment1_length, normalize(thumbJoint1 - thumbJoint0), thumbJoint0)
            
            basis = HandBasis(palmTangent: palmTangent, upDirection: upDirection, wristPosition: wristPosition,
                              thumbJoint1: thumbJoint1, thumbDirection2: thumbDirection2)
        }
    }
    
}

extension HandModelFitter.HandBasis {
    
    var objects: [ARObject] {
        var output = [ARObject](capacity: 10)
        
        func makeArrow(direction: simd_float3, start: simd_float3 = wristPosition,
                       size: Float = 0.055, color: simd_float3)
        {
            let baseEnd = fma(direction, max(0.005, size - 0.015), start)
            
            if let base = ARObject(roundShapeType: .cylinder,
                                   bottomPosition: start,
                                   topPosition: baseEnd,
                                   diameter: 0.0105,
                                   
                                   color: color,
                                   shininess: 8) {
                output.append(base)
            }
            
            let tipEnd = fma(direction, simd_float3(repeating: 0.015), baseEnd)
            
            if let tip = ARObject(roundShapeType: .cone,
                                  bottomPosition: baseEnd,
                                  topPosition:     tipEnd,
                                  diameter: 0.015,
                                  
                                  color: color,
                                  shininess: 8) {
                output.append(tip)
            }
        }
        
        makeArrow(direction: palmTangent, color: [0.5, 0.5, 0.1])
        makeArrow(direction: upDirection, color: [0.7, 0.1, 0.1])
        
        let thumbJoint1_length = length(thumbJoint1)
        makeArrow(direction: thumbJoint1 / thumbJoint1_length, start: wristPosition,
                       size: thumbJoint1_length,               color: [0.8, 0.8, 1.0])
        
        makeArrow(direction: thumbDirection2, start: thumbJoint1 + wristPosition,
                       size: 0.040,           color: [0.60, 0.35, 0.70])
        
        return output
    }
    
}
#endif

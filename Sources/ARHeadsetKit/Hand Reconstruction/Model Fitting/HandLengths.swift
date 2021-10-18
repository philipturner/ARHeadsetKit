//
//  HandLengths.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 5/12/21.
//

import simd

extension HandModelFitter {
    
    struct HandLengthHistory: DelegateHandModelFitter {
        private var history: [HandLengths]
        var count: Int { history.count }
        
        // This data structure periodically resets its in-place
        // length sum to prevent rounding errors from accumulating
        private var lengths = HandLengths.zero
        private var secondLengths = HandLengths.defaultLengths
        private var cycleIndex = 0
        
        // Used to substitute incorrect lengths with something reasonable
        private var originalAverageLengths = HandLengths.zero
        
        init() {
            history = [HandLengths](capacity: 256)
        }
        
        mutating func append(_ input: ReconstructedHand) {
            guard let handComponent0 = input.components[0] else { return }
            guard let handComponent1 = input.components[1] else { return }
            guard let handComponent2 = input.components[2] else { return }
            guard let handComponent3 = input.components[3] else { return }
            guard let handComponent4 = input.components[4] else { return }
            guard let handComponent5 = input.components[5] else { return }
            
            var currentLengths = HandLengths(
                handComponent0: handComponent0,
                handComponent1: handComponent1,
                handComponent2: handComponent2,
                handComponent3: handComponent3,
                handComponent4: handComponent4,
                handComponent5: handComponent5
            )
            
            if count == 256 {
                originalAverageLengths.purify(averageLengths: .defaultLengths)
                currentLengths.purify(averageLengths: originalAverageLengths)
                
                if cycleIndex >= 13 * 256 {
                    if cycleIndex == 13 * 256 {
                        secondLengths = currentLengths
                    } else {
                        secondLengths += currentLengths
                    }
                    
                    if cycleIndex == 14 * 256 - 1 {
                        cycleIndex = 0
                        lengths = secondLengths
                        
                        history[255] = currentLengths
                        originalAverageLengths = secondLengths * (1.0 / 256)
                        return
                    }
                }
                
                let historyIndex = cycleIndex & 255
                cycleIndex += 1
                
                lengths -= history[historyIndex]
                lengths += currentLengths
                
                history[historyIndex] = currentLengths
                originalAverageLengths = lengths * (1.0 / 256)
            } else {
                if count < 16 {
                    currentLengths.purify(averageLengths: .defaultLengths)
                } else {
                    originalAverageLengths.purify(averageLengths: .defaultLengths)
                    currentLengths.purify(averageLengths: originalAverageLengths)
                }
                
                if count == 0 {
                    lengths = currentLengths
                } else {
                    lengths += currentLengths
                }
                
                history.append(currentLengths)
                originalAverageLengths = lengths * recip(Float(count))
            }
        }
        
        var averageLengths: HandLengths {
            if count >= 32 {
                return originalAverageLengths
            } else if count == 0 {
                return secondLengths
            } else {
                return .mix(secondLengths, originalAverageLengths, (1.0 / 32) * Float(count))
            }
        }
    }
    
}

extension HandModelFitter {
    
    struct HandLengths {
        private var connections1: simd_float4
        private var connections2: simd_float4
        private var connections3: simd_float4
        private var connections4: simd_float4
        private var connections5: simd_float4
        private var connections6: simd_float4
        
        static var zero: Self {
            Self(connections1: .zero,
                 connections2: .zero,
                 connections3: .zero,
                 connections4: .zero,
                 connections5: .zero,
                 connections6: .zero)
        }
        
        static let defaultLengths = Self(
            wristConnections: [0.031, 0.081, 0.081, 0.080, 0.0725],
            betweenFingerConnections: [0.063, 0.023, 0.019, 0.023],
            insideFingerConnections: [
                [0.032, 0.028, 0.025],
                [0.031, 0.024, 0.02 ],
                [0.036, 0.030, 0.02 ],
                [0.033, 0.028, 0.02 ],
                [0.025, 0.021, 0.02 ]
            ]
        )
        
        init(connections1: simd_float4,
             connections2: simd_float4,
             connections3: simd_float4,
             connections4: simd_float4,
             connections5: simd_float4,
             connections6: simd_float4)
        {
            self.connections1 = connections1
            self.connections2 = connections2
            self.connections3 = connections3
            self.connections4 = connections4
            self.connections5 = connections5
            self.connections6 = connections6
        }
        
        init(wristConnections         w:  [Float],
             betweenFingerConnections b:  [Float],
             insideFingerConnections  i: [[Float]])
        {
            connections1 = .init(w   [0], w   [1], w   [2], w   [3])
            connections2 = .init(w   [4], b   [0], b   [1], b   [2])
            connections3 = .init(b   [3], i[0][0], i[0][1], i[0][2])
            connections4 = .init(i[1][0], i[1][1], i[1][2], i[2][0])
            connections5 = .init(i[2][1], i[2][2], i[3][0], i[3][1])
            connections6 = .init(i[3][2], i[4][0], i[4][1], i[4][2])
        }
        
        init(handComponent0: HandComponent,
             handComponent1: HandComponent,
             handComponent2: HandComponent,
             handComponent3: HandComponent,
             handComponent4: HandComponent,
             handComponent5: HandComponent)
        {
            var swizzleSource1: simd_float3
            var swizzleSource2: simd_float3
            var swizzleSource3: simd_float3
            var swizzleSource4: simd_float3
            
            func getNextLengths() -> simd_float4 {
                let out = dotAdd(swizzleSource1, swizzleSource1,
                                 swizzleSource2, swizzleSource2,
                                 swizzleSource3, swizzleSource3,
                                 swizzleSource4, swizzleSource4)
                
                return sqrt(out)
            }
            
            
            
            let wrist = handComponent0[0]
            
            let thumbBase = handComponent1[0]
            swizzleSource1 = thumbBase - wrist
            
            let indexKnuckle = handComponent2[0]
            swizzleSource2 = indexKnuckle - wrist
            
            let middleKnuckle = handComponent3[0]
            swizzleSource3 = middleKnuckle - wrist
            
            let ringKnuckle = handComponent4[0]
            swizzleSource4 = ringKnuckle - wrist
            
            connections1 = getNextLengths()
            
            
            
            let littleKnuckle = handComponent5[0]
            swizzleSource1 = littleKnuckle - wrist
            
            swizzleSource2 = indexKnuckle - thumbBase
            swizzleSource3 = middleKnuckle - indexKnuckle
            swizzleSource4 = ringKnuckle - middleKnuckle
            
            connections2 = getNextLengths()
            
            
            
            swizzleSource1 = littleKnuckle - ringKnuckle
            
            let thumbKnuckle = handComponent1[1]
            swizzleSource2 = thumbKnuckle - thumbBase
            
            let thumbJoint1 = handComponent1[2]
            swizzleSource3 = thumbJoint1 - thumbKnuckle
            
            let thumbJoint2 = handComponent1[3]
            swizzleSource4 = thumbJoint2 - thumbJoint1
            
            connections3 = getNextLengths()
            
            
            
            let indexJoint1 = handComponent2[1]
            swizzleSource1 = indexJoint1 - indexKnuckle
            
            let indexJoint2 = handComponent2[2]
            swizzleSource2 = indexJoint2 - indexJoint1
            
            let indexJoint3 = handComponent2[3]
            swizzleSource3 = indexJoint3 - indexJoint2
            
            let middleJoint1 = handComponent3[1]
            swizzleSource4 = middleJoint1 - middleKnuckle
            
            connections4 = getNextLengths()
            
            
            
            let middleJoint2 = handComponent3[2]
            swizzleSource1 = middleJoint2 - middleJoint1
            
            let middleJoint3 = handComponent3[3]
            swizzleSource2 = middleJoint3 - middleJoint2
            
            let ringJoint1 = handComponent4[1]
            swizzleSource3 = ringJoint1 - ringKnuckle
            
            let ringJoint2 = handComponent4[2]
            swizzleSource4 = ringJoint2 - ringJoint1
            
            connections5 = getNextLengths()
            
            
            
            let ringJoint3 = handComponent4[3]
            swizzleSource1 = ringJoint3 - ringJoint2
            
            let littleJoint1 = handComponent5[1]
            swizzleSource2 = littleJoint1 - littleKnuckle
            
            let littleJoint2 = handComponent5[2]
            swizzleSource3 = littleJoint2 - littleJoint1
            
            let littleJoint3 = handComponent5[3]
            swizzleSource4 = littleJoint3 - littleJoint2
            
            connections6 = getNextLengths()
        }
    }
    
}
    
extension HandModelFitter.HandLengths {
    
    @inline(__always)
    func getWristConnection(fingerID: Int) -> Float {
        if fingerID == 4 {
            return connections2[0]
        } else {
            return connections1[fingerID]
        }
    }
    
    @inline(__always)
    func getBetweenFingerConnection(endFingerID: Int) -> Float {
        if endFingerID == 4 {
            return connections3[0]
        } else {
            return connections2[endFingerID]
        }
    }
    
    @inline(__always)
    func getInsideFingerConnection(fingerID: Int, endJointID: Int) -> Float {
        if fingerID < 2 {
            if fingerID == 0 {
                return connections3[endJointID]
            } else {
                return connections4[endJointID - 1]
            }
        } else if fingerID < 4 {
            if fingerID == 2 {
                if endJointID == 1 {
                    return connections4[3]
                } else {
                    return connections5[endJointID - 2]
                }
            } else {
                if endJointID <= 2 {
                    return connections5[endJointID + 1]
                } else {
                    return connections6[endJointID - 3]
                }
            }
        } else {
            return connections6[endJointID]
        }
    }
    
    var scale: Float {
        let palmSegmentScales = simd_float4(
            getWristConnection(fingerID: 1),
            getWristConnection(fingerID: 2),
            getWristConnection(fingerID: 3),
            getWristConnection(fingerID: 4)
        ) / .init(
            Self.defaultLengths.getWristConnection(fingerID: 1),
            Self.defaultLengths.getWristConnection(fingerID: 2),
            Self.defaultLengths.getWristConnection(fingerID: 3),
            Self.defaultLengths.getWristConnection(fingerID: 4)
        )
        
        let fingerSegmentScales = simd_float4(
            0,
            getInsideFingerConnection(fingerID: 1, endJointID: 1),
            getInsideFingerConnection(fingerID: 2, endJointID: 1),
            getInsideFingerConnection(fingerID: 3, endJointID: 1)
        ) / .init(
            1,
            Self.defaultLengths.getInsideFingerConnection(fingerID: 1, endJointID: 1),
            Self.defaultLengths.getInsideFingerConnection(fingerID: 2, endJointID: 1),
            Self.defaultLengths.getInsideFingerConnection(fingerID: 3, endJointID: 1)
        )
        
        return fma(fingerSegmentScales, 7.0 / 6, palmSegmentScales).sum() * (2.0 / 15)
    }
    
    
    
    static func += (lhs: inout Self, rhs: Self) {
        lhs.connections1 += rhs.connections1
        lhs.connections2 += rhs.connections2
        lhs.connections3 += rhs.connections3
        lhs.connections4 += rhs.connections4
        lhs.connections5 += rhs.connections5
        lhs.connections6 += rhs.connections6
    }
    
    static func -= (lhs: inout Self, rhs: Self) {
        lhs.connections1 -= rhs.connections1
        lhs.connections2 -= rhs.connections2
        lhs.connections3 -= rhs.connections3
        lhs.connections4 -= rhs.connections4
        lhs.connections5 -= rhs.connections5
        lhs.connections6 -= rhs.connections6
    }
    
    static func * (lhs: Self, rhs: Float) -> Self {
        Self(connections1: lhs.connections1 * rhs,
             connections2: lhs.connections2 * rhs,
             connections3: lhs.connections3 * rhs,
             connections4: lhs.connections4 * rhs,
             connections5: lhs.connections5 * rhs,
             connections6: lhs.connections6 * rhs)
    }
    
    static func mix(_ x: Self, _ y: Self, _ t: Float) -> Self {
        let t_vector = simd_float4(repeating: t)
        
        return Self(
            connections1: fma(y.connections1 - x.connections1, t_vector, x.connections1),
            connections2: fma(y.connections2 - x.connections2, t_vector, x.connections2),
            connections3: fma(y.connections3 - x.connections3, t_vector, x.connections3),
            connections4: fma(y.connections4 - x.connections4, t_vector, x.connections4),
            connections5: fma(y.connections5 - x.connections5, t_vector, x.connections5),
            connections6: fma(y.connections6 - x.connections6, t_vector, x.connections6)
        )
    }
    
    mutating func purify(averageLengths: Self) {
        if connections6[3] + connections6[2] > connections6[0] + connections5[3] {
            connections6[3] = connections6[0]
            connections6[2] = connections5[3]
        }
        
        var mask1 = .!(connections1 .> Self.defaultLengths.connections1 * 0.4)
        var mask2 = .!(connections2 .> Self.defaultLengths.connections2 * 0.4)
        var mask3 = .!(connections3 .> Self.defaultLengths.connections3 * 0.4)
        var mask4 = .!(connections4 .> Self.defaultLengths.connections4 * 0.4)
        var mask5 = .!(connections5 .> Self.defaultLengths.connections5 * 0.4)
        var mask6 = .!(connections6 .> Self.defaultLengths.connections6 * 0.4)
        
        mask1 .|= .!(connections1 .< Self.defaultLengths.connections1 * 1.95)
        mask2 .|= .!(connections2 .< Self.defaultLengths.connections2 * 1.95)
        mask3 .|= .!(connections3 .< Self.defaultLengths.connections3 * 1.95)
        mask4 .|= .!(connections4 .< Self.defaultLengths.connections4 * 1.95)
        mask5 .|= .!(connections5 .< Self.defaultLengths.connections5 * 1.95)
        mask6 .|= .!(connections6 .< Self.defaultLengths.connections6 * 1.95)
        
        if any(mask1) { connections1.replace(with: averageLengths.connections1, where: mask1) }
        if any(mask2) { connections2.replace(with: averageLengths.connections2, where: mask2) }
        
        // Ensure each finger tip segment is 0.5 to 1.25 times
        // the length of the segment connected to it
        
        let comparison1_lhs = simd_float2(connections3[3], connections4[2])
        let comparison1_rhs = simd_float2(connections3[2], connections4[1])
        
        var mask7 = fma(comparison1_rhs, simd_float2(repeating: -0.5),  comparison1_lhs) .< 0
        mask7   .|= fma(comparison1_rhs, simd_float2(repeating: -1.25), comparison1_lhs) .> 0
        
        mask3[3] = mask3[3] || mask7[0]
        mask4[2] = mask4[2] || mask7[1]
        
        let comparison2_lhs = simd_float3(connections5[1], connections6[0], connections6[3])
        let comparison2_rhs = simd_float3(connections5[0], connections5[3], connections6[2])
        
        var mask8 = fma(comparison2_rhs, simd_float3(repeating: -0.5),  comparison2_lhs) .< 0
        mask8   .|= fma(comparison2_rhs, simd_float3(repeating: -1.25), comparison2_lhs) .> 0
        
        mask5[1] = mask5[1] || mask8[0]
        mask6[0] = mask6[0] || mask8[1]
        mask6[3] = mask6[3] || mask8[2]
        
        var replacements3: simd_float4
        var replacements4: simd_float4
        var replacements5: simd_float4
        var replacements6: simd_float4
        
        if any(mask3) {
            replacements3 = averageLengths.connections3
            replacements3[3] = replacements3[2]
            
            connections3.replace(with: replacements3, where: mask3)
        }
        
        if any(mask4) {
            replacements4 = averageLengths.connections4
            replacements4[2] = replacements4[1]
            
            connections4.replace(with: replacements4, where: mask4)
        }
        
        if any(mask5) {
            replacements5 = averageLengths.connections5
            replacements5[1] = replacements5[0]
            
            connections5.replace(with: replacements5, where: mask5)
        }
        
        if any(mask6) {
            replacements6 = averageLengths.connections6
            replacements6[3] = replacements6[2]
            replacements6[0] = averageLengths.connections5[3]
            
            connections6.replace(with: replacements6, where: mask6)
        }
    }
    
}

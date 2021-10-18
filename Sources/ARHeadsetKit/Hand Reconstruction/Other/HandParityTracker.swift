//
//  HandParityTracker.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/25/21.
//

import simd

struct HandParityTracker: DelegateHandRenderer {
    private static let historyLength = 16
    
    private var history = [simd_ushort2](repeating: .zero, count: historyLength)
    private var cycleIndex = 0
    private var sum = simd_long2.zero
    
    mutating func append(leftHandEvidence: Int, rightHandEvidence: Int) {
        if leftHandEvidence == 0, rightHandEvidence == 0 { return }
        
        sum &-= simd_long2(truncatingIfNeeded: history[cycleIndex])
        
        let newEvidence = simd_long2(leftHandEvidence, rightHandEvidence)
        sum &+= newEvidence
        
        history[cycleIndex] = simd_ushort2(clamping: newEvidence)
        cycleIndex = (cycleIndex + 1) & (Self.historyLength - 1)
    }
    
    var shouldRenderRight: Bool {
        sum.y >= sum.x
    }
}

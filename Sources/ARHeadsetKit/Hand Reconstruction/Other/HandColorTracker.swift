//
//  HandColorTracker.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/24/21.
//

import simd

struct HandColorTracker: DelegateHandRenderer {
    private var colorHistory = Array(repeating: simd_half3(repeating: .nan), count: 5)
    private var historyIndex = 0
    
    mutating func append(_ input: simd_half3) {
        colorHistory[historyIndex] = input
        
        if historyIndex == 4 {
            historyIndex = 0
        } else {
            historyIndex += 1
        }
    }
    
    var color: simd_float3 {
        var numColors = 0
        var accumulatedColor = simd_float3(repeating: 0)
        
        for i in 0..<5 {
            let retrievedColor = colorHistory[i]
            
            if !retrievedColor.x.isNaN {
                numColors += 1
                accumulatedColor += simd_float3(retrievedColor)
            }
        }
        
        if numColors == 5 {
            return accumulatedColor * 0.2
        } else {
            return accumulatedColor * simd_fast_recip(Float(numColors))
        }
    }
}

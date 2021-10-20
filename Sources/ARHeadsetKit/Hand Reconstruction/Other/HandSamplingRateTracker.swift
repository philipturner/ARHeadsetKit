//
//  HandSamplingRateTracker.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/26/21.
//

#if !os(macOS)
import Foundation
import simd

struct HandSamplingRateTracker: DelegateHandRenderer {
    private static let historyLength = 16
    private static let maxNumQuickSamples = historyLength >> 1
    
    private var history = [UInt8](repeating: 24, count: historyLength)
    private var cycleIndex = 0
    private var numQuickSamples = 0
    var targetSamplingLevel = 2
    
    private var sampleFailureStreak = 0
    
    mutating func registerSampleStart(samplingRate: Int) {
        let retrievedSamplingRate = history[cycleIndex]
        
        if retrievedSamplingRate < 6 {
            if samplingRate >= 6 {
                numQuickSamples -= 1
            }
        } else if samplingRate < 6 {
            numQuickSamples += 1
        }
        
        history[cycleIndex] = UInt8(clamping: samplingRate)
        cycleIndex = (cycleIndex + 1) & (Self.historyLength - 1)
    }
    
    mutating func registerSampleCompletion(didSucceed: Bool) {
        if didSucceed {
            sampleFailureStreak = 0
        } else {
            sampleFailureStreak += 1
        }
    }
    
    var samplingRate: Int {
        var retrievedSamplingLevel = targetSamplingLevel
        
        if numQuickSamples >= Self.maxNumQuickSamples {
            retrievedSamplingLevel = max(1, retrievedSamplingLevel)
        }
        
        if retrievedSamplingLevel < 2, sampleFailureStreak >= 3 {
            retrievedSamplingLevel >>= 1
        }
        
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return 3 << retrievedSamplingLevel
        case .fair:     return 3 << retrievedSamplingLevel
        case .serious:  return 4 << retrievedSamplingLevel
        case .critical: return 100_000_000
        @unknown default: fatalError("This thermal state is not possible!")
        }
    }
}
#endif

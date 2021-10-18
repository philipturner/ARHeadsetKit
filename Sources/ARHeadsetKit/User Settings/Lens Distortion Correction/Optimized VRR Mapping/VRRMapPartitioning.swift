//
//  VRRMapPartitioning.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/10/21.
//

import Metal
import simd

extension LensDistortionCorrector {
    
    struct VRRPartition: Equatable {
        var origins0: simd_ushort4
        var origins1: simd_ushort4
        
        var checkpoints0: simd_ushort4
        var checkpoints1: simd_ushort4
    }
    
    struct VRRFullPartition: Equatable {
        var lowerXPartition: VRRPartition
        var upperXPartition: VRRPartition
        
        var lowerYPartition: VRRPartition
        var upperYPartition: VRRPartition
    }
    
    func partitionVRRMap() -> VRRFullPartition? {
        let granularity = vrrMap.physicalGranularity
        let physicalSize = vrrMap.physicalSize(layer: 0)
        
        let originsX = createVRRSamples(sampleStepSize: granularity.width,  totalSampleSize: physicalSize.width)
        let originsY = createVRRSamples(sampleStepSize: granularity.height, totalSampleSize: physicalSize.height)
        
        let checkpointsX = executeVRRSampleX(origins: originsX, vrrMap: vrrMap)
        let checkpointsY = executeVRRSampleY(origins: originsY, vrrMap: vrrMap)
        
        let intermediateSideLengthHalf = intermediateSideLength >> 1
        
        let (lowerMergedX, upperMergedX) = detectCheckpoints(originsX, checkpointsX, intermediateSideLengthHalf)
        if lowerMergedX.count > 9 || upperMergedX.count > 9 { return nil }
        
        let (lowerMergedY, upperMergedY) = detectCheckpoints(originsY, checkpointsY, intermediateSideLengthHalf)
        if lowerMergedY.count > 9 || upperMergedY.count > 9 { return nil }
        
        let lowerXPartition = createVRRPartition(mergedSample: lowerMergedX, isUpper: false)
        let upperXPartition = createVRRPartition(mergedSample: upperMergedX, isUpper: true)
        
        let lowerYPartition = createVRRPartition(mergedSample: lowerMergedY, isUpper: false)
        let upperYPartition = createVRRPartition(mergedSample: upperMergedY, isUpper: true)
        
        return .init(lowerXPartition: lowerXPartition, upperXPartition: upperXPartition,
                     lowerYPartition: lowerYPartition, upperYPartition: upperYPartition)
    }
    
    fileprivate typealias VRRIntSample = (regularSamples: [Int], edgeSample: Int?)
    fileprivate typealias VRRMergedSample = [(vrrCoord: Int, screenCoord: Int)]
    
    fileprivate func createVRRSamples(sampleStepSize: Int, totalSampleSize: Int) -> VRRIntSample {
        let sampleStepSizeShift = 63 - sampleStepSize.leadingZeroBitCount
        let outputSize = totalSampleSize >> sampleStepSizeShift + 1
        
        let output = [Int](unsafeUninitializedCapacity: outputSize) { pointer, count in
            count = outputSize
            
            for i in 0..<outputSize {
                pointer[i] = i << sampleStepSizeShift
            }
        }
        
        let edgeSample = (totalSampleSize & (sampleStepSize - 1) == 0) ? nil : totalSampleSize
        
        return (output, edgeSample)
    }
    
    fileprivate func executeVRRSampleX(origins: VRRIntSample, vrrMap: MTLRasterizationRateMap) -> VRRIntSample {
        var output = [Int](capacity: origins.regularSamples.count)
        var outputEdgeSample: Int?
        
        @inline(__always)
        func sampleX(_ coordX: Int) -> Int {
            let output = vrrMap.screenCoordinates(physicalCoordinates: [ Float(coordX), 10 ], layer: 0)
            return Int(round(output.x))
        }
        
        for sample in origins.regularSamples {
            output.append(sampleX(sample))
        }
        
        if let inputEdgeSample = origins.edgeSample {
            outputEdgeSample = sampleX(inputEdgeSample)
        }
        
        return (output, outputEdgeSample)
    }
    
    fileprivate func executeVRRSampleY(origins: VRRIntSample, vrrMap: MTLRasterizationRateMap) -> VRRIntSample {
        var output = [Int](capacity: origins.regularSamples.count)
        var outputEdgeSample: Int?
        
        @inline(__always)
        func sampleY(_ coordY: Int) -> Int {
            let output = vrrMap.screenCoordinates(physicalCoordinates: [ 10, Float(coordY) ], layer: 0)
            return Int(round(output.y))
        }
        
        for sample in origins.regularSamples {
            output.append(sampleY(sample))
        }
        
        if let inputEdgeSample = origins.edgeSample {
            outputEdgeSample = sampleY(inputEdgeSample)
        }
        
        return (output, outputEdgeSample)
    }
    
    fileprivate func detectCheckpoints(_ vrrCoords: VRRIntSample, _ screenCoords: VRRIntSample,
                                       _ intermediateSideLengthHalf: Int) -> (half1: VRRMergedSample, half2: VRRMergedSample)
    {
        var output1 = VRRMergedSample(capacity: 9)
        var output2 = VRRMergedSample(capacity: 9)
        
        func appendOutput(_ vrrCoord: Int, _ screenCoord: Int) {
            if screenCoord <= intermediateSideLengthHalf {
                output1.append((vrrCoord, screenCoord))
            } else {
                output2.append((vrrCoord, screenCoord))
            }
        }
        
        let firstScreenCoord = screenCoords.regularSamples[0]
        output1.append((vrrCoords.regularSamples[0], firstScreenCoord))
        
        var previousScreenCoord = screenCoords.regularSamples[1]
        var previousScreenDelta = previousScreenCoord - firstScreenCoord
        
        let numSamples_minus1 = screenCoords.regularSamples.count - 1
        
        for i in 2...numSamples_minus1 {
            let currentScreenCoord = screenCoords.regularSamples[i]
            let currentScreenDelta = currentScreenCoord - previousScreenCoord
            
            if currentScreenDelta != previousScreenDelta {
                let previousVRRCoord = vrrCoords.regularSamples[i - 1]
                appendOutput(previousVRRCoord, previousScreenCoord)
                
                previousScreenDelta = currentScreenDelta
            }
            
            previousScreenCoord = currentScreenCoord
        }
        
        if let screenEdgeSample = screenCoords.edgeSample {
            let vrrEdgeSample = vrrCoords.edgeSample!
            
            let currentScreenDelta = screenEdgeSample - previousScreenCoord
            
            let beforePreviousVRRCoord = vrrCoords.regularSamples[numSamples_minus1 - 1]
            let previousVRRCoord       = vrrCoords.regularSamples[numSamples_minus1]
            
            let previousVRRDelta = previousVRRCoord - beforePreviousVRRCoord
            let currentVRRDelta  = vrrEdgeSample - previousVRRCoord
            
            if currentVRRDelta * previousScreenDelta != previousVRRDelta * currentScreenDelta {
                appendOutput(previousVRRCoord, previousScreenCoord)
            }
            
            output2.append((vrrEdgeSample, screenEdgeSample))
        } else {
            let previousVRRCoord = vrrCoords.regularSamples[numSamples_minus1]
            output2.append((previousVRRCoord, previousScreenCoord))
        }
        
        return (output1, output2)
    }
    
}

extension LensDistortionCorrector {
    
    private func partition(_ weights: [Int]) -> [Int] {
        if weights.count < 5 {
            switch weights.count {
            case 0:
                return [0]
            case 1:
                return [0, 8]
            case 2:
                return [0, 4, 8]
            case 3:
                if weights[0] < weights[2] {
                    return [0, 2, 4, 8]
                } else {
                    return [0, 4, 6, 8]
                }
            default:
                return [0, 2, 4, 6, 8]
            }
        } else if weights.count < 8 {
            var maxIndex = 0
            var maxWeight = weights[0]
            
            for i in 1..<weights.count {
                let retrievedWeight = weights[i]
                
                if retrievedWeight > maxWeight {
                    maxWeight = retrievedWeight
                    maxIndex = i
                }
            }
            
            switch weights.count {
            case 5:
                if maxIndex == 3 || maxIndex == 4 {
                    return [0, 1, 2, 4, 6, 8]
                } else {
                    return [0, 2, 4, 6, 7, 8]
                }
            case 6:
                if maxIndex == 4 || maxIndex == 5 {
                    return [0, 1, 2, 3, 4, 6, 8]
                } else if maxIndex == 2 || maxIndex == 3 {
                    return [0, 1, 2, 4, 6, 7, 8]
                } else {
                    return [0, 2, 4, 5, 6, 7, 8]
                }
            default:
                var output = [0, 1, 2, 3, 4, 5, 6, 7, 8]
                
                if maxIndex & 1 == 0 {
                    output.remove(at: maxIndex + 1)
                } else {
                    output.remove(at: 1)
                }
                
                return output
            }
        } else {
            return [0, 1, 2, 3, 4, 5, 6, 7, 8]
        }
    }
    
    fileprivate func createVRRPartition(mergedSample input: VRRMergedSample, isUpper: Bool) -> VRRPartition {
        let numWeights = input.count - 1
        
        let weights = [Int](unsafeUninitializedCapacity: numWeights) { pointer, count in
            count = numWeights
            var end = input[numWeights].screenCoord
            
            for i in (0..<numWeights).reversed() {
                let start = input[i].screenCoord
                pointer[i] = end - start
                
                end = start
            }
        }
        
        let partitionIndices = partition(weights)
        
        var origins     = [Int](repeating: 0, count: 9)
        var checkpoints = [Int](repeating: 0, count: 9)
        
        for i in 0..<numWeights + 1 {
            let partitionIndex = partitionIndices[i]
            
            (origins[partitionIndex], checkpoints[partitionIndex]) = input[i]
        }
        
        let startIndex = isUpper ? 0 : 1
        
        @inline(__always)
        func makeOutputElement(_ array: [Int], _ i: Int) -> simd_ushort4 {
            .init(UInt16(array[startIndex + i]),
                  UInt16(array[startIndex + i + 1]),
                  UInt16(array[startIndex + i + 2]),
                  UInt16(array[startIndex + i + 3]))
        }
        
        return .init(
            origins0:     makeOutputElement(origins, 0),
            origins1:     makeOutputElement(origins, 4),
            checkpoints0: makeOutputElement(checkpoints, 0),
            checkpoints1: makeOutputElement(checkpoints, 4)
        )
    }
    
}

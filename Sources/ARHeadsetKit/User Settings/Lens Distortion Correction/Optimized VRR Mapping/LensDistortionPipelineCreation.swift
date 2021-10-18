//
//  LensDistortionPipelineCreation.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/10/21.
//

import Metal
import simd

extension LensDistortionCorrector {
    
    func createVRRMap(fullRateProportionX: Float, fullRateProportionY: Float) -> MTLRasterizationRateMap {
        let numHalfRatePixelsX = Int(round(Float(intermediateSideLength) * (1 - fullRateProportionX)))
        let numHalfRatePixelsY = Int(round(Float(intermediateSideLength) * (1 - fullRateProportionY)))
        
        let numFullRatePixelsX = intermediateSideLength - numHalfRatePixelsX
        let numFullRatePixelsY = intermediateSideLength - numHalfRatePixelsY
        
        let edgeSizeX = numHalfRatePixelsX >> 1
        let edgeSizeY = numHalfRatePixelsY >> 1
        
        func createSamplingRates(edgeSize: Int, centerSize: Int) -> [Float] {
            var samplingRates = [Float](unsafeUninitializedCount: edgeSize << 1 + centerSize)
            var pointer = samplingRates.unsafeMutablePointer!
            memset_pattern4(pointer, 0.49, count: edgeSize)
            
            pointer += edgeSize
            memset_pattern4(pointer, 1.00, count: centerSize)
            
            pointer += centerSize
            memset_pattern4(pointer, 0.49, count: edgeSize)
            
            return samplingRates
        }
        
        let horizontalSamplingRates = createSamplingRates(edgeSize: edgeSizeX, centerSize: numFullRatePixelsX)
        let verticalSamplingRates   = createSamplingRates(edgeSize: edgeSizeY, centerSize: numFullRatePixelsY)
        
        let layerDescriptor = MTLRasterizationRateLayerDescriptor(horizontal: horizontalSamplingRates,
                                                                  vertical:   verticalSamplingRates)
        
        let rasterizationRateMapDescriptor = MTLRasterizationRateMapDescriptor()
        rasterizationRateMapDescriptor.screenSize = [intermediateSideLength, intermediateSideLength]
        rasterizationRateMapDescriptor.layers[0] = layerDescriptor
        rasterizationRateMapDescriptor.layers[1] = layerDescriptor
        rasterizationRateMapDescriptor.optLabel = "Rasterization Rate Map"
        
        return device.makeRasterizationRateMap(descriptor: rasterizationRateMapDescriptor)!
    }
    
    func createOptimizedLensDistortionPipeline() {
        let constants = MTLFunctionConstantValues()
        constants.setConstantValue(&intermediateSideLength, type: .ushort, index: 0)
        
        var intermediateTextureDimensions_ushort2 = simd_ushort2(truncatingIfNeeded: intermediateTextureDimensions)
        constants.setConstantValue(&intermediateTextureDimensions_ushort2, type: .ushort2, index: 1)
        
        
        
        guard var fullPartition = partitionVRRMap() else {
            newOptimizedCorrectLensDistortionPipelineState = nil
            return
        }
        
        guard fullPartition != previousVRRPartition || intermediateSideLength != previousIntermediateSideLength else {
            newOptimizedCorrectLensDistortionPipelineState = optimizedCorrectLensDistortionPipelineState
            return
        }
        
        previousVRRPartition = fullPartition
        previousIntermediateSideLength = intermediateSideLength
        
        let x_checkpoints_1 = fullPartition.lowerXPartition.checkpoints1
        let x_checkpoints_2 = fullPartition.upperXPartition.checkpoints0
        let y_checkpoints_1 = fullPartition.lowerYPartition.checkpoints1
        let y_checkpoints_2 = fullPartition.upperYPartition.checkpoints0
        
        let middleDeltas = simd_ushort2(x_checkpoints_2[0], y_checkpoints_2[0])
                        &- simd_ushort2(x_checkpoints_1[3], y_checkpoints_1[3])
        
        let middleRatios = simd_float2(middleDeltas) / Float(intermediateSideLength)
        
        var checkingMiddleX = middleRatios.x > 0.50
        var checkingMiddleY = middleRatios.y > 0.50
        
        constants.setConstantValue(&checkingMiddleX, type: .bool, index: 2)
        constants.setConstantValue(&checkingMiddleY, type: .bool, index: 3)
        
        
        
        constants.setConstantValue(&fullPartition.lowerXPartition.origins0,     type: .ushort4, index: 10)
        constants.setConstantValue(&fullPartition.lowerXPartition.origins1,     type: .ushort4, index: 11)
        constants.setConstantValue(&fullPartition.upperXPartition.origins0,     type: .ushort4, index: 12)
        constants.setConstantValue(&fullPartition.upperXPartition.origins1,     type: .ushort4, index: 13)
        
        constants.setConstantValue(&fullPartition.lowerXPartition.checkpoints0, type: .ushort4, index: 14)
        constants.setConstantValue(&fullPartition.lowerXPartition.checkpoints1, type: .ushort4, index: 15)
        constants.setConstantValue(&fullPartition.upperXPartition.checkpoints0, type: .ushort4, index: 16)
        constants.setConstantValue(&fullPartition.upperXPartition.checkpoints1, type: .ushort4, index: 17)
        
        constants.setConstantValue(&fullPartition.lowerYPartition.origins0,     type: .ushort4, index: 20)
        constants.setConstantValue(&fullPartition.lowerYPartition.origins1,     type: .ushort4, index: 21)
        constants.setConstantValue(&fullPartition.upperYPartition.origins0,     type: .ushort4, index: 22)
        constants.setConstantValue(&fullPartition.upperYPartition.origins1,     type: .ushort4, index: 23)
        
        constants.setConstantValue(&fullPartition.lowerYPartition.checkpoints0, type: .ushort4, index: 24)
        constants.setConstantValue(&fullPartition.lowerYPartition.checkpoints1, type: .ushort4, index: 25)
        constants.setConstantValue(&fullPartition.upperYPartition.checkpoints0, type: .ushort4, index: 26)
        constants.setConstantValue(&fullPartition.upperYPartition.checkpoints1, type: .ushort4, index: 27)
        
        
        
        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        computePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        computePipelineDescriptor.computeFunction = try! renderer.library.makeFunction(name: "optimizedCorrectLensDistortion",
                                                                                       constantValues: constants)
        computePipelineDescriptor.optLabel = "Optimized Correct Lens Distortion Pipeline"
        newOptimizedCorrectLensDistortionPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
    }
    
}

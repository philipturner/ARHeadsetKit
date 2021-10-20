//
//  OpticalFlowMeasurementExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 5/29/21.
//

#if !os(macOS)
import Metal
import simd

extension OpticalFlowMeasurer {
    
    func updateResources() {
        guard doingSample else {
            doingSample = true
            handRenderer.didWaitOnSegmentationTextureSemaphore = false
            return
        }
        
        doingSample = false
        
        var offset2Index = self.offset2Index + 1
        var offset4Index = self.offset4Index + 1
        var offset8Index = self.offset8Index + 1
        
        if      offset2Index >= 8 / 2 { offset2Index = 0 }
        else if offset4Index >= 8 / 2 { offset4Index = 0 }
        else if offset8Index >= 8 / 2 { offset8Index = 0 }
        
        self.offset2Index = offset2Index
        self.offset4Index = offset4Index
        self.offset8Index = offset8Index
        
        handRenderer.didWaitOnSegmentationTextureSemaphore = true
        
        if !isMeasuring {
            let sample = pendingSample
            currentSample = sample
            
            if !(sample[2] > 0) {
                handRenderer.targetSamplingLevel = 3
            } else if sample[0] < 25 {
                handRenderer.targetSamplingLevel = 2
            } else if sample[1] < 50 {
                handRenderer.targetSamplingLevel = 1
            } else {
                handRenderer.targetSamplingLevel = 0
            }
            
            handRenderer.segmentationTextureSemaphore.wait()
            measureOpticalFlow()
        } else {
            handRenderer.segmentationTextureSemaphore.wait()
            
            if let newDepthTexture = sceneDepthTexture,
               let newSegmentationTexture = segmentationTexture {
                copyTextures(newDepthTexture:        newDepthTexture,
                             newSegmentationTexture: newSegmentationTexture)
                
                texturePresenceHistory[offset8Index] = true
            } else {
                texturePresenceHistory[offset8Index] = false
            }
        }
    }
    
    func copyTextures(newDepthTexture: MTLTexture, newSegmentationTexture: MTLTexture) {
        let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer.optLabel = "Copy Optical Flow Textures Command Buffer"
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Copy Optical Flow Textures - Overwrite Old Texture"
        
        let oldTexturePair = texturePairHistory[offset8Index]
        blitEncoder.copy(from: newDepthTexture,        to: oldTexturePair.depth)
        blitEncoder.copy(from: newSegmentationTexture, to: oldTexturePair.segmentation)
        blitEncoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    func measureOpticalFlow() {
        guard let newDepthTexture = sceneDepthTexture,
              let newSegmentationTexture = segmentationTexture else {
            texturePresenceHistory[offset8Index] = false
            currentSample[0] = .nan
            return
        }
        
        guard !texturePresenceHistory.contains(false) else {
            copyTextures(newDepthTexture:        newDepthTexture,
                         newSegmentationTexture: newSegmentationTexture)
            
            texturePresenceHistory[offset8Index] = true
            currentSample[0] = .nan
            return
        }
        
        isMeasuring = true
        
        
        
        let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer.optLabel = "Optical Flow Measurement Command Buffer"
        commandBuffer.addCompletedHandler { [unowned self] _ in
            handleOpticalFlowReturn()
        }
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Optical Flow Measurement - Compute Pass"
        
        let pair8 = texturePairHistory[offset8Index]
        let pair4 = texturePairHistory[offset4Index]
        
        computeEncoder.setTexture(pair8.depth,            index: 0)
        computeEncoder.setTexture(pair4.depth,            index: 1)
        computeEncoder.setTexture(newDepthTexture,        index: 2)
        
        computeEncoder.setTexture(pair8.segmentation,     index: 3)
        computeEncoder.setTexture(pair4.segmentation,     index: 4)
        computeEncoder.setTexture(newSegmentationTexture, index: 5)
        
        computeEncoder.setComputePipelineState(poolOpticalFlow256PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .regionSamples256, index: 0)
        computeEncoder.dispatchThreadgroups([64 / 4, 96 / 8], threadsPerThreadgroup: [4, 8])
        
        computeEncoder.setComputePipelineState(poolOpticalFlow8192PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .regionSamples8192, index: 1)
        computeEncoder.dispatchThreadgroups(6, threadsPerThreadgroup: 32)
        
        computeEncoder.endEncoding()
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Optical Flow Measurement - Overwrite Old Depth Texture"
        
        blitEncoder.copy(from: newDepthTexture, to: pair8.depth)
        blitEncoder.endEncoding()
        
        commandBuffer.commit()
    }
    
    func handleOpticalFlowReturn() {
        let regionSamplePointer = bridgeBuffer[.regionSamples8192].assumingMemoryBound(to: SIMD3<Float16>.self)
        var output = simd_float3(regionSamplePointer[0])
        
        for i in 1..<6 {
            output += simd_float3(regionSamplePointer[i])
        }
        
        pendingSample = output
        isMeasuring = false
    }
    
}
#endif

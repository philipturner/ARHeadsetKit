//
//  OpticalFlowMeasurer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 5/29/21.
//

import Metal
import simd

final class OpticalFlowMeasurer: DelegateRenderer, DelegateHandRenderer {
    unowned let renderer: MainRenderer
    var handRenderer: HandRenderer { renderer.handRenderer }
    
    var isMeasuring = false
    var currentSample = simd_float3(repeating: .nan)
    var pendingSample = simd_float3(repeating: .nan)
    
    struct TexturePair {
        var depth: MTLTexture
        var segmentation: MTLTexture
        
        init?(_ depth: MTLTexture?, _ segmentation: MTLTexture?) {
            guard let depth = depth,
                  let segmentation = segmentation else {
                return nil
            }
            
            self.depth = depth
            self.segmentation = segmentation
        }
    }
    
    var texturePresenceHistory = Array(repeating: false, count: 4)
    var texturePairHistory: [(depth: MTLTexture, segmentation: MTLTexture)]
    
    var doingSample = true
    
    var offset2Index = (8 - 2) / 2
    var offset4Index = (8 - 4) / 2
    var offset8Index = (8 - 8) / 2
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case regionSamples256
        case regionSamples8192
        
        static let bufferLabel = "Optical Flow Measurer Bridge Buffer"
        
        func getSize(capacity _: Int) -> Int {
            switch self {
            case .regionSamples256:  return 192 * MemoryLayout<simd_half3>.stride
            case .regionSamples8192: return   6 * MemoryLayout<simd_half3>.stride
            }
        }
    }
    
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    
    var poolOpticalFlow256PipelineState: MTLComputePipelineState
    var poolOpticalFlow8192PipelineState: MTLComputePipelineState
    
    init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
        let device = renderer.device
        
        bridgeBuffer = device.makeLayeredBuffer(capacity: 1, options: .storageModeShared)
        
        
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.width  = 256
        textureDescriptor.height = 192
        
        textureDescriptor.storageMode = .private
        textureDescriptor.pixelFormat = .r32Float
        textureDescriptor.usage = .shaderRead
        
        let depthTextures = (0..<4).map { i -> MTLTexture in
            let texture = device.makeTexture(descriptor: textureDescriptor)!
            texture.optLabel = "Optical Flow Measurer Cycled Depth Texture \(i)"
            
            return texture
        }
        
        textureDescriptor.pixelFormat = .r8Unorm
        textureDescriptor.usage = [.shaderRead, .shaderWrite]
        
        let segmentationTextures = (0..<4).map { i -> MTLTexture in
            let texture = device.makeTexture(descriptor: textureDescriptor)!
            texture.optLabel = "Optical Flow Measurer Cycled Segmentation Texture \(i)"
            
            return texture
        }
        
        texturePairHistory = (0..<4).map {
            (depthTextures[$0], segmentationTextures[$0])
        }
        
        
        
        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        computePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        
        computePipelineDescriptor.computeFunction = library.makeFunction(name: "poolOpticalFlow256")
        computePipelineDescriptor.optLabel = "Optical Flow Measurer Pool Optical Flow 256 Pipeline"
        poolOpticalFlow256PipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        computePipelineDescriptor.computeFunction = library.makeFunction(name: "poolOpticalFlow8192")
        computePipelineDescriptor.optLabel = "Optical Flow Measurer Pool Optical Flow 8192 Pipeline"
        poolOpticalFlow8192PipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
    }
    
    deinit {
        while isMeasuring {
            usleep(100)
        }
    }
}

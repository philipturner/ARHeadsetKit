//
//  SceneTexelRasterizer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import simd

final class SceneTexelRasterizer: DelegateSceneRenderer {
    unowned let sceneRenderer: SceneRenderer
    
    var preCullTriangleCount: Int { sceneMeshReducer.preCullTriangleCount }
    var newReducedIndexBuffer: MTLBuffer { sceneMeshMatcher.newReducedIndexBuffer }
    var newReducedVertexBuffer: MTLBuffer { sceneMeshMatcher.newReducedVertexBuffer }
    var newReducedColorBuffer: MTLBuffer { sceneMeshMatcher.newReducedColorBuffer }
    
    var oldReducedColorBuffer: MTLBuffer { sceneMeshMatcher.oldReducedColorBuffer }
    var newToOldTriangleMatchesBuffer: MTLBuffer { sceneMeshMatcher.newToOldTriangleMatchesBuffer }
    var newToOldMatchWindingBuffer: MTLBuffer { sceneMeshMatcher.newToOldMatchWindingBuffer }
    
    typealias TriangleMarkLayer = SceneTexelManager.TriangleMarkLayer
    typealias SmallColorLayer = SceneTexelManager.SmallColorLayer
    typealias LargeColorLayer = SceneTexelManager.LargeColorLayer
    
    var oldTriangleMarkBuffer: MTLLayeredBuffer<TriangleMarkLayer> { sceneTexelManager.oldTriangleMarkBuffer }
    var smallTriangleColorBuffer: MTLLayeredBuffer<SmallColorLayer> { sceneTexelManager.smallTriangleColorBuffer }
    var largeTriangleColorBuffer: MTLLayeredBuffer<LargeColorLayer> { sceneTexelManager.largeTriangleColorBuffer }
    
    enum TriangleDataLayer: UInt16, MTLBufferLayer {
        case texelCount
        case texelOffset
        case texelOffsets256
        
        case columnCount
        case columnOffset
        case columnOffsets256
        
        static let bufferLabel = "Scene Texel Rasterizer Triangle Data Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .texelCount:       return capacity * MemoryLayout<UInt8>.stride
            case .texelOffset:      return capacity * MemoryLayout<UInt16>.stride
            case .texelOffsets256:  return capacity >> 8 * MemoryLayout<UInt32>.stride
            
            case .columnCount:      return capacity * MemoryLayout<UInt8>.stride
            case .columnOffset:     return capacity * MemoryLayout<UInt16>.stride
            case .columnOffsets256: return capacity >> 8 * MemoryLayout<UInt32>.stride
            }
        }
    }
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case haveChangedMark
        case compressedHaveChangedMark
        
        case columnCounts16
        case columnCounts64
        case columnCounts256
        case columnCounts1024
        case columnCounts4096
        
        case columnOffsets4096
        case columnOffsets1024
        case columnOffsets64
        case columnOffsets16
        
        case texelCounts16
        case texelCounts64
        case texelCounts256
        case texelCounts1024
        case texelCounts4096
        
        case texelOffsets4096
        case texelOffsets1024
        case texelOffsets64
        case texelOffsets16
        
        case matchExistsMark
        case triangleCount
        
        static let bufferLabel = "Scene Texel Rasterizer Bridge Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .haveChangedMark:           return capacity * MemoryLayout<UInt8>.stride
            case .compressedHaveChangedMark: return capacity * MemoryLayout<UInt16>.stride
            
            case .columnCounts16:            return capacity >>  4 * MemoryLayout<UInt16>.stride
            case .columnCounts64:            return capacity >>  6 * MemoryLayout<UInt16>.stride
            case .columnCounts256:           return capacity >>  8 * MemoryLayout<UInt16>.stride
            case .columnCounts1024:          return capacity >> 10 * MemoryLayout<UInt32>.stride
            case .columnCounts4096:          return capacity >> 12 * MemoryLayout<UInt32>.stride
            
            case .columnOffsets4096:         return capacity >> 12 * MemoryLayout<UInt32>.stride
            case .columnOffsets1024:         return capacity >> 10 * MemoryLayout<UInt32>.stride
            case .columnOffsets64:           return capacity >>  6 * MemoryLayout<UInt16>.stride
            case .columnOffsets16:           return capacity >>  4 * MemoryLayout<UInt16>.stride
                
            case .texelCounts16:             return capacity >>  4 * MemoryLayout<UInt16>.stride
            case .texelCounts64:             return capacity >>  6 * MemoryLayout<UInt16>.stride
            case .texelCounts256:            return capacity >>  8 * MemoryLayout<UInt16>.stride
            case .texelCounts1024:           return capacity >> 10 * MemoryLayout<UInt32>.stride
            case .texelCounts4096:           return capacity >> 12 * MemoryLayout<UInt32>.stride
            
            case .texelOffsets4096:          return capacity >> 12 * MemoryLayout<UInt32>.stride
            case .texelOffsets1024:          return capacity >> 10 * MemoryLayout<UInt32>.stride
            case .texelOffsets64:            return capacity >>  6 * MemoryLayout<UInt16>.stride
            case .texelOffsets16:            return capacity >>  4 * MemoryLayout<UInt16>.stride
                
            case .matchExistsMark:           return capacity * MemoryLayout<Bool>.stride
            case .triangleCount:             return MemoryLayout<UInt32>.stride
            }
        }
    }
    
    enum TexelLayer: UInt16, MTLBufferLayer {
        case luma
        case chroma
        
        static let bufferLabel = "Scene Texel Rasterizer Texel Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .luma:   return capacity * MemoryLayout<simd_uchar4>.stride
            case .chroma: return capacity * MemoryLayout<simd_uchar2>.stride
            }
        }
    }
    
    var triangleDataBuffer: MTLLayeredBuffer<TriangleDataLayer>
    var oldTriangleDataBuffer: MTLLayeredBuffer<TriangleDataLayer>
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    var texelBuffer: MTLLayeredBuffer<TexelLayer>
    
    var rasterizationComponentBuffer: MTLBuffer
    var oldRasterizationComponentBuffer: MTLBuffer
    
    var expandedColumnOffsetBuffer: MTLBuffer
    var oldExpandedColumnOffsetBuffer: MTLBuffer
    
    var rasterizeTexelsPipelineState: MTLComputePipelineState
    var countTexels64PipelineState: MTLComputePipelineState
    var scanTexels256PipelineState: MTLComputePipelineState
    var countTexels1024PipelineState: MTLComputePipelineState
    var countTexels4096PipelineState: MTLComputePipelineState
    
    var markTexelOffsets4096PipelineState: MTLComputePipelineState
    var markTexelOffsets1024PipelineState: MTLComputePipelineState
    var markTexelOffsets64PipelineState: MTLComputePipelineState
    var markTexelOffsets16PipelineState: MTLComputePipelineState
    
    var transferColorDataToBufferPipelineState: MTLComputePipelineState
    
    init(sceneRenderer: SceneRenderer, library: MTLLibrary) {
        self.sceneRenderer = sceneRenderer
        let device = sceneRenderer.device
        
        let triangleCapacity = 65536
        let columnCapacity   = 262144
        let texelCapacity    = 1048576
        
        triangleDataBuffer    = device.makeLayeredBuffer(capacity: triangleCapacity)
        oldTriangleDataBuffer = device.makeLayeredBuffer(capacity: triangleCapacity)
        bridgeBuffer          = device.makeLayeredBuffer(capacity: triangleCapacity, options: .storageModeShared)
        texelBuffer           = device.makeLayeredBuffer(capacity: texelCapacity)
        
        debugLabel { [triangleDataBuffer, oldTriangleDataBuffer] in
            triangleDataBuffer.label    = "New " + TriangleDataLayer.bufferLabel
            oldTriangleDataBuffer.label = "Old " + TriangleDataLayer.bufferLabel
        }
        
        
        
        let rasterizationComponentBufferSize = triangleCapacity * MemoryLayout<simd_float3>.stride
        rasterizationComponentBuffer = device.makeBuffer(length: rasterizationComponentBufferSize, options: .storageModePrivate)!
        rasterizationComponentBuffer.optLabel = "Scene Texel Rasterizer Rasterization Component Buffer"
        
        oldRasterizationComponentBuffer = device.makeBuffer(length: rasterizationComponentBufferSize, options: .storageModePrivate)!
        oldRasterizationComponentBuffer.optLabel = "(Old) Scene Texel Rasterizer Rasterization Component Buffer"
        
        let expandedColumnOffsetBufferSize = columnCapacity * MemoryLayout<UInt8>.stride
        expandedColumnOffsetBuffer = device.makeBuffer(length: expandedColumnOffsetBufferSize, options: .storageModePrivate)!
        expandedColumnOffsetBuffer.optLabel = "Scene Texel Rasterizer Expanded Column Offset Buffer"
        
        oldExpandedColumnOffsetBuffer = device.makeBuffer(length: expandedColumnOffsetBufferSize, options: .storageModePrivate)!
        oldExpandedColumnOffsetBuffer.optLabel = "(Old) Scene Texel Rasterizer Expanded Column Offset Buffer"
        
        
        
        rasterizeTexelsPipelineState = library.makeComputePipeline(Self.self, name: "rasterizeTexels")
        countTexels64PipelineState   = library.makeComputePipeline(Self.self, name: "countTexels64")
        scanTexels256PipelineState   = library.makeComputePipeline(Self.self, name: "scanTexels256")
        countTexels1024PipelineState = library.makeComputePipeline(Self.self, name: "countTexels1024")
        countTexels4096PipelineState = library.makeComputePipeline(Self.self, name: "countTexels4096")
        
        markTexelOffsets4096PipelineState = library.makeComputePipeline(Self.self, name: "markTexelOffsets4096")
        markTexelOffsets1024PipelineState = library.makeComputePipeline(Self.self, name: "markTexelOffsets1024")
        markTexelOffsets64PipelineState   = library.makeComputePipeline(Self.self, name: "markTexelOffsets64")
        markTexelOffsets16PipelineState   = library.makeComputePipeline(Self.self, name: "markTexelOffsets16")
        
        transferColorDataToBufferPipelineState = library.makeComputePipeline(Self.self, name: "transferColorDataToBuffer")
    }
}

extension SceneTexelRasterizer: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case triangle
        case triangleData
        case column
        case texel
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .triangle:     bridgeBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .triangleData: ensureTriangleDataCapacity(capacity: newCapacity)
        case .column:       ensureColumnCapacity(capacity: newCapacity)
        case .texel:        texelBuffer.ensureCapacity(device: device, capacity: newCapacity)
        }
    }
    
    private func ensureTriangleDataCapacity(capacity: Int) {
        let rasterizationComponentBufferSize = capacity * MemoryLayout<simd_float3>.stride
        if rasterizationComponentBuffer.length < rasterizationComponentBufferSize {
            rasterizationComponentBuffer = device.makeBuffer(length: rasterizationComponentBufferSize, options: .storageModePrivate)!
            rasterizationComponentBuffer.optLabel = "Scene Texel Rasterizer Rasterization Component Buffer"
        } else {
            return
        }
        
        triangleDataBuffer.changeCapacity(device: device, capacity: capacity)
    }
    
    private func ensureColumnCapacity(capacity: Int) {
        let expandedColumnOffsetBufferSize = capacity * MemoryLayout<UInt8>.stride
        if expandedColumnOffsetBuffer.length < expandedColumnOffsetBufferSize {
            expandedColumnOffsetBuffer = device.makeBuffer(length: expandedColumnOffsetBufferSize, options: .storageModePrivate)!
            expandedColumnOffsetBuffer.optLabel = "Scene Texel Rasterizer Expanded Column Offset Buffer"
        }
    }
    
}
#endif

//
//  SecondSceneSorter.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

final class SecondSceneSorter: DelegateSceneSorter {
    unowned let sceneSorter: SceneSorter
    
    struct OctantCounts_8bit {
        var lowerCounts: simd_uchar4
        var upperCounts: simd_uchar4
    }
    
    struct OctantCounts_16bit {
        var lowerCounts: simd_ushort4
        var upperCounts: simd_ushort4
    }
    
    struct OctantOffsets_32bit {
        var lowerMarks: simd_uint4
        var upperMarks: simd_uint4
    }
    
    var smallSectorSize: Float!
    var previousCommandBuffer2: MTLCommandBuffer?
    
    var sourceVertexBuffer: MTLBuffer
    var destinationVertexBuffer: MTLBuffer
    
    enum LargeSectorLayer: UInt16, MTLBufferLayer {
        case bounds
        case numVertexThreads
        
        static let bufferLabel = "Second Scene Sorter Large Sector Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .bounds:           return capacity * MemoryLayout<simd_float2x3>.stride
            case .numVertexThreads: return capacity * MemoryLayout<UInt32>.stride
            }
        }
    }
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case idBufferOffsets2048
        
        case octantMark
        case octantCounts16
        case octantCounts128
        case octantCounts2048
        
        case octantOffsets2048
        case octantOffsets128
        case octantOffsets16
        
        static let bufferLabel = "Second Scene Sorter Bridge Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .idBufferOffsets2048: return capacity >> 11 * MemoryLayout<UInt32>.stride
            
            case .octantMark:          return capacity       * MemoryLayout<UInt8>.stride
            case .octantCounts16:      return capacity >>  4 * MemoryLayout<OctantCounts_8bit>.stride
            case .octantCounts128:     return capacity >>  7 * MemoryLayout<OctantCounts_8bit>.stride
            case .octantCounts2048:    return capacity >> 11 * MemoryLayout<OctantCounts_16bit>.stride
            
            case .octantOffsets2048:   return capacity >> 11 * MemoryLayout<OctantOffsets_32bit>.stride
            case .octantOffsets128:    return capacity >>  7 * MemoryLayout<OctantOffsets_32bit>.stride
            case .octantOffsets16:     return capacity >>  4 * MemoryLayout<OctantOffsets_32bit>.stride
            }
        }
    }
    
    var largeSectorBuffer: MTLLayeredBuffer<LargeSectorLayer>
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    
    var markLargeSectorOctantsPipelineState: MTLComputePipelineState
    var poolLargeSectorOctantCounts16PipelineState: MTLComputePipelineState
    var poolLargeSectorOctantCounts128PipelineState: MTLComputePipelineState
    var poolLargeSectorOctantCounts2048PipelineState: MTLComputePipelineState
    
    var markLargeSectorOctantOffsets2048PipelineState: MTLComputePipelineState
    var markLargeSectorOctantOffsets128PipelineState: MTLComputePipelineState
    var fillLargeSectorOctantsPipelineState: MTLComputePipelineState
    
    init(sceneSorter: SceneSorter, library: MTLLibrary) {
        self.sceneSorter = sceneSorter
        let device = sceneSorter.device
        
        let largeSectorCapacity = 8
        let vertexCapacity = 32768
        
        largeSectorBuffer = device.makeLayeredBuffer(capacity: largeSectorCapacity, options: .storageModeShared)
        bridgeBuffer = device.makeLayeredBuffer(capacity: vertexCapacity, options: .storageModeShared)
        
        let vertexBufferSize = vertexCapacity * MemoryLayout<UInt32>.stride
        sourceVertexBuffer = device.makeBuffer(length: vertexBufferSize, options: .storageModePrivate)!
        sourceVertexBuffer.optLabel = "Second Scene Sorter Vertex Buffer (Not Used Yet)"
        
        destinationVertexBuffer = device.makeBuffer(length: vertexBufferSize, options: .storageModePrivate)!
        destinationVertexBuffer.optLabel = "Second/Third Scene Sorter Destination Vertex Buffer"
        
        markLargeSectorOctantsPipelineState          = library.makeComputePipeline(Self.self, name: "markLargeSectorOctants")
        poolLargeSectorOctantCounts16PipelineState   = library.makeComputePipeline(Self.self, name: "poolLargeSectorOctantCounts16")
        poolLargeSectorOctantCounts128PipelineState  = library.makeComputePipeline(Self.self, name: "poolLargeSectorOctantCounts128")
        poolLargeSectorOctantCounts2048PipelineState = library.makeComputePipeline(Self.self, name: "poolLargeSectorOctantCounts2048")
        
        markLargeSectorOctantOffsets2048PipelineState = library.makeComputePipeline(Self.self, name: "markLargeSectorOctantOffsets2048")
        markLargeSectorOctantOffsets128PipelineState  = library.makeComputePipeline(Self.self, name: "markLargeSectorOctantOffsets128")
        fillLargeSectorOctantsPipelineState           = library.makeComputePipeline(Self.self, name: "fillLargeSectorOctants")
    }
}

extension SecondSceneSorter: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case largeSector
        case vertex
        case bridge
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .largeSector: largeSectorBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .vertex:      ensureVertexCapacity(capacity: newCapacity)
        case .bridge:      bridgeBuffer.ensureCapacity(device: device, capacity: newCapacity)
        }
    }
    
    private func ensureVertexCapacity(capacity: Int) {
        let destinationVertexBufferSize = capacity * MemoryLayout<UInt32>.stride
        if destinationVertexBuffer.length < destinationVertexBufferSize {
            destinationVertexBuffer = device.makeBuffer(length: destinationVertexBufferSize, options: .storageModePrivate)!
            destinationVertexBuffer.optLabel = "Second/Third Scene Sorter Destination Vertex Buffer"
        }
    }
    
}

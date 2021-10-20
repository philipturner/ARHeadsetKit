//
//  FirstSceneSorter.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import simd

final class FirstSceneSorter: DelegateSceneSorter {
    unowned let sceneSorter: SceneSorter
    
    struct OctantData_8bit {
        var lowerCounts: simd_uchar4
        var upperCounts: simd_uchar4
        
        struct Sizes {
            var lower: simd_uchar4
            var upper: simd_uchar4
        }
        var sizes: Sizes
    }
    
    struct OctantData_16bit {
        var lowerCounts: simd_ushort4
        var upperCounts: simd_ushort4
        
        struct Sizes {
            var lower: simd_uchar4
            var upper: simd_uchar4
        }
        var sizes: Sizes
    }
    
    struct OctantOffsets_32bit {
        var lowerMarks: simd_uint4
        var upperMarks: simd_uint4
    }
    
    var destinationVertexBuffer: MTLBuffer { secondSceneSorter.destinationVertexBuffer }
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case octantMark
        case octantData16
        case octantData256
        case octantData4096
        
        case octantOffsets4096
        case octantOffsets256
        case octantOffsets16
        
        case numVertexThreads
        
        static let bufferLabel = "First Scene Sorter Bridge Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .octantMark:        return capacity       * MemoryLayout<simd_uchar2>.stride
            case .octantData16:      return capacity >>  4 * MemoryLayout<OctantData_8bit>.stride
            case .octantData256:     return capacity >>  8 * MemoryLayout<OctantData_16bit>.stride
            case .octantData4096:    return capacity >> 12 * MemoryLayout<OctantData_16bit>.stride
                
            case .octantOffsets4096: return capacity >> 12 * MemoryLayout<OctantOffsets_32bit>.stride
            case .octantOffsets256:  return capacity >>  8 * MemoryLayout<OctantOffsets_32bit>.stride
            case .octantOffsets16:   return capacity >>  4 * MemoryLayout<OctantOffsets_32bit>.stride
                
            case .numVertexThreads:  return MemoryLayout<UInt32>.stride
            }
        }
    }
    
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    
    var markWorldOctantsPipelineState: MTLComputePipelineState
    var poolWorldOctantData16PipelineState: MTLComputePipelineState
    var poolWorldOctantData256PipelineState: MTLComputePipelineState
    var poolWorldOctantData4096PipelineState: MTLComputePipelineState
    
    var markWorldOctantOffsets4096PipelineState: MTLComputePipelineState
    var markWorldOctantOffsets256PipelineState: MTLComputePipelineState
    var fillWorldOctantsPipelineState: MTLComputePipelineState
    
    init(sceneSorter: SceneSorter, library: MTLLibrary) {
        self.sceneSorter = sceneSorter
        let device = sceneSorter.device
        
        let vertexCapacity = 32768
        
        bridgeBuffer = device.makeLayeredBuffer(capacity: vertexCapacity, options: .storageModeShared)
        
        markWorldOctantsPipelineState        = library.makeComputePipeline(Self.self, name: "markWorldOctants")
        poolWorldOctantData16PipelineState   = library.makeComputePipeline(Self.self, name: "poolWorldOctantData16")
        poolWorldOctantData256PipelineState  = library.makeComputePipeline(Self.self, name: "poolWorldOctantData256")
        poolWorldOctantData4096PipelineState = library.makeComputePipeline(Self.self, name: "poolWorldOctantData4096")
        
        markWorldOctantOffsets4096PipelineState = library.makeComputePipeline(Self.self, name: "markWorldOctantOffsets4096")
        markWorldOctantOffsets256PipelineState  = library.makeComputePipeline(Self.self, name: "markWorldOctantOffsets256")
        fillWorldOctantsPipelineState           = library.makeComputePipeline(Self.self, name: "fillWorldOctants")
    }
}

extension FirstSceneSorter: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case vertex
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .vertex: bridgeBuffer.ensureCapacity(device: device, capacity: newCapacity)
        }
    }
    
}
#endif

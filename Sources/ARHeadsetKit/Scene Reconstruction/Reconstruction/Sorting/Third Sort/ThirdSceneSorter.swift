//
//  ThirdSceneSorter.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

final class ThirdSceneSorter: DelegateSceneSorter {
    unowned let sceneSorter: SceneSorter
    
    var sourceVertexBuffer: MTLBuffer { secondSceneSorter.sourceVertexBuffer }
    var destinationVertexBuffer: MTLBuffer {
        get { secondSceneSorter.destinationVertexBuffer }
        set { secondSceneSorter.destinationVertexBuffer = newValue }
    }
    
    enum VertexDataLayer: UInt16, MTLBufferLayer {
        case smallSectorID
        case microSectorID
        case subsectorData
        
        static let bufferLabel = "Third/Fourth Scene Sorter Vertex Data Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .smallSectorID: return capacity >> 7 * MemoryLayout<UInt16>.stride
            case .microSectorID: return capacity >> 4 * MemoryLayout<UInt16>.stride
            case .subsectorData: return capacity * 32
            }
        }
    }
    
    enum MicroSector512thLayer: UInt16, MTLBufferLayer {
        case counts
        case offsets
        
        static let bufferLabel = "Third Scene Sorter Micro Sector 512th Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .counts:  return capacity << 9 * MemoryLayout<UInt32>.stride
            case .offsets: return capacity << 9 * MemoryLayout<UInt16>.stride
            }
        }
    }
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case smallSector256GroupOffset
        case smallSectorCount
        case smallSectorOffset
        case smallSectorBounds
        
        case counts128th
        case counts32nd
        case counts8th
        case countsHalf
        case counts2
        
        case numMicroSectors128th
        case numMicroSectors32nd
        case numMicroSectors8th
        case numMicroSectorsHalf
        case numMicroSectors2
        
        case microSector32GroupCounts128th
        case microSector32GroupCounts32nd
        case microSector32GroupCounts8th
        case microSector32GroupCountsHalf
        case microSector32GroupCounts2
        
        case offsets2
        case offsetsHalf
        case offsets8th
        case offsets32nd
        case offsets128th
        
        case microSectorOffsets2
        case microSectorOffsetsHalf
        case microSectorOffsets8th
        case microSectorOffsets32nd
        case microSectorOffsets128th
        
        case microSector32GroupOffsets2
        case microSector32GroupOffsetsHalf
        case microSector32GroupOffsets8th
        case microSector32GroupOffsets32nd
        case microSector32GroupOffsets128th
        
        static let bufferLabel = "Third Scene Sorter Bridge Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .smallSector256GroupOffset:      return capacity * MemoryLayout<UInt16>.stride + 16
            case .smallSectorCount:               return capacity * MemoryLayout<UInt16>.stride
            case .smallSectorOffset:              return capacity * MemoryLayout<UInt32>.stride
            case .smallSectorBounds:              return capacity * MemoryLayout<simd_float2x3>.stride
                
            case .counts128th:                    return capacity << 7 * MemoryLayout<UInt16>.stride
            case .counts32nd:                     return capacity << 5 * MemoryLayout<UInt16>.stride
            case .counts8th:                      return capacity << 3 * MemoryLayout<UInt16>.stride
            case .countsHalf:                     return capacity << 1 * MemoryLayout<UInt16>.stride
            case .counts2:                        return capacity >> 1 * MemoryLayout<UInt16>.stride
                
            case .numMicroSectors128th:           return capacity << 7 * MemoryLayout<UInt8>.stride
            case .numMicroSectors32nd:            return capacity << 5 * MemoryLayout<UInt8>.stride
            case .numMicroSectors8th:             return capacity << 3 * MemoryLayout<UInt8>.stride
            case .numMicroSectorsHalf:            return capacity << 1 * MemoryLayout<UInt16>.stride
            case .numMicroSectors2:               return capacity >> 1 * MemoryLayout<UInt16>.stride
                
            case .microSector32GroupCounts128th:  return capacity << 7 * MemoryLayout<UInt8>.stride
            case .microSector32GroupCounts32nd:   return capacity << 5 * MemoryLayout<UInt8>.stride
            case .microSector32GroupCounts8th:    return capacity << 3 * MemoryLayout<UInt8>.stride
            case .microSector32GroupCountsHalf:   return capacity << 1 * MemoryLayout<UInt16>.stride
            case .microSector32GroupCounts2:      return capacity >> 1 * MemoryLayout<UInt16>.stride
                
            case .offsets2:                       return capacity >> 1 * MemoryLayout<UInt32>.stride
            case .offsetsHalf:                    return capacity << 1 * MemoryLayout<UInt16>.stride
            case .offsets8th:                     return capacity << 3 * MemoryLayout<UInt16>.stride
            case .offsets32nd:                    return capacity << 5 * MemoryLayout<UInt16>.stride
            case .offsets128th:                   return capacity << 7 * MemoryLayout<UInt16>.stride
                
            case .microSectorOffsets2:            return capacity >> 1 * MemoryLayout<UInt16>.stride
            case .microSectorOffsetsHalf:         return capacity << 1 * MemoryLayout<UInt16>.stride
            case .microSectorOffsets8th:          return capacity << 3 * MemoryLayout<UInt16>.stride
            case .microSectorOffsets32nd:         return capacity << 5 * MemoryLayout<UInt16>.stride
            case .microSectorOffsets128th:        return capacity << 7 * MemoryLayout<UInt16>.stride
                
            case .microSector32GroupOffsets2:     return capacity >> 1 * MemoryLayout<UInt16>.stride
            case .microSector32GroupOffsetsHalf:  return capacity << 1 * MemoryLayout<UInt16>.stride
            case .microSector32GroupOffsets8th:   return capacity << 3 * MemoryLayout<UInt16>.stride
            case .microSector32GroupOffsets32nd:  return capacity << 5 * MemoryLayout<UInt16>.stride
            case .microSector32GroupOffsets128th: return capacity << 7 * MemoryLayout<UInt16>.stride
            }
        }
    }
    
    enum MicroSectorLayer: UInt16, MTLBufferLayer {
        case countsFinal
        case offsetsFinal
        
        case microSector32GroupOffsetsFinal
        case microSectorToSmallSectorMappings
        case microSectorIDsInSmallSectors
        
        static let bufferLabel = "Third Scene Sorter Micro Sector Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .countsFinal:                      return capacity * MemoryLayout<UInt16>.stride
            case .offsetsFinal:                     return capacity * MemoryLayout<UInt16>.stride
            
            case .microSector32GroupOffsetsFinal:   return capacity * MemoryLayout<UInt16>.stride
            case .microSectorToSmallSectorMappings: return capacity * MemoryLayout<UInt16>.stride
            case .microSectorIDsInSmallSectors:     return capacity * MemoryLayout<UInt16>.stride
            }
        }
    }
    
    var vertexDataBuffer: MTLLayeredBuffer<VertexDataLayer>
    var microSector512thBuffer: MTLLayeredBuffer<MicroSector512thLayer>
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    var microSectorBuffer: MTLLayeredBuffer<MicroSectorLayer>
    
    var prepareMarkMicroSectorsPipelineState: MTLComputePipelineState
    var markMicroSectorsPipelineState: MTLComputePipelineState
    var poolSmallSector128thCountsPipelineState: MTLComputePipelineState
    var poolSmallSector32ndTo8thCountsPipelineState: MTLComputePipelineState
    var poolSmallSectorHalfCountsPipelineState: MTLComputePipelineState
    var scanSmallSectors2PipelineState: MTLComputePipelineState
    
    var markSmallSectorHalfTo32ndOffsetsPipelineState: MTLComputePipelineState
    var markSmallSector128thOffsetsPipelineState: MTLComputePipelineState
    var fillMicroSectorsPipelineState: MTLComputePipelineState
    
    init(sceneSorter: SceneSorter, library: MTLLibrary) {
        self.sceneSorter = sceneSorter
        let device = sceneSorter.device
        
        let smallSectorCapacity = 16
        let microSectorCapacity = 64
        let vertexCapacity = 32768
        
        vertexDataBuffer       = device.makeLayeredBuffer(capacity: vertexCapacity)
        microSector512thBuffer = device.makeLayeredBuffer(capacity: smallSectorCapacity)
        bridgeBuffer           = device.makeLayeredBuffer(capacity: smallSectorCapacity, options: .storageModeShared)
        microSectorBuffer      = device.makeLayeredBuffer(capacity: microSectorCapacity)
        
        prepareMarkMicroSectorsPipelineState        = library.makeComputePipeline(Self.self, name: "prepareMarkMicroSectors")
        markMicroSectorsPipelineState               = library.makeComputePipeline(Self.self, name: "markMicroSectors")
        poolSmallSector128thCountsPipelineState     = library.makeComputePipeline(Self.self, name: "poolSmallSector128thCounts")
        poolSmallSector32ndTo8thCountsPipelineState = library.makeComputePipeline(Self.self, name: "poolSmallSector32ndTo8thCounts")
        poolSmallSectorHalfCountsPipelineState      = library.makeComputePipeline(Self.self, name: "poolSmallSectorHalfCounts")
        scanSmallSectors2PipelineState              = library.makeComputePipeline(Self.self, name: "scanSmallSectors2")
        
        markSmallSectorHalfTo32ndOffsetsPipelineState = library.makeComputePipeline(Self.self, name: "markSmallSectorHalfTo32ndOffsets")
        markSmallSector128thOffsetsPipelineState      = library.makeComputePipeline(Self.self, name: "markSmallSector128thOffsets")
        fillMicroSectorsPipelineState                 = library.makeComputePipeline(Self.self, name: "fillMicroSectors")
    }
}

extension ThirdSceneSorter: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case smallSector
        case initialVertex
        case finalVertex
        case microSector
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .smallSector:   ensureSmallSectorCapacity(capacity: newCapacity)
        case .initialVertex: vertexDataBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .finalVertex:   ensureFinalVertexCapacity(capacity: newCapacity)
        case .microSector:   microSectorBuffer.ensureCapacity(device: device, capacity: newCapacity)
        }
    }
    
    private func ensureSmallSectorCapacity(capacity: Int) {
        microSector512thBuffer.ensureCapacity(device: device, capacity: capacity)
        bridgeBuffer          .ensureCapacity(device: device, capacity: capacity)
    }
    
    private func ensureFinalVertexCapacity(capacity: Int) {
        let destinationVertexBufferSize = capacity * MemoryLayout<UInt32>.stride
        if destinationVertexBuffer.length < destinationVertexBufferSize {
            destinationVertexBuffer = device.makeBuffer(length: destinationVertexBufferSize, options: .storageModePrivate)!
            destinationVertexBuffer.optLabel = "Second/Third Scene Sorter Destination Vertex Buffer"
        }
    }
    
}

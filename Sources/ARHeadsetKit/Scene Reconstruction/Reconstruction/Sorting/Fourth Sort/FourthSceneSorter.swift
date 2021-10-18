//
//  FourthSceneSorter.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

final class FourthSceneSorter: DelegateSceneSorter {
    unowned let sceneSorter: SceneSorter
    
    typealias SourceBridgeLayer = ThirdSceneSorter.BridgeLayer
    typealias SourceMicroSectorLayer = ThirdSceneSorter.MicroSectorLayer
    
    var sourceVertexBuffer: MTLBuffer { thirdSceneSorter.destinationVertexBuffer }
    var sourceBridgeBuffer: MTLLayeredBuffer<SourceBridgeLayer> { thirdSceneSorter.bridgeBuffer }
    var sourceMicroSectorBuffer: MTLLayeredBuffer<SourceMicroSectorLayer> { thirdSceneSorter.microSectorBuffer }
    
    typealias VertexDataLayer = ThirdSceneSorter.VertexDataLayer
    var vertexDataBuffer: MTLLayeredBuffer<VertexDataLayer> {
        get { thirdSceneSorter.vertexDataBuffer }
        set { thirdSceneSorter.vertexDataBuffer = newValue }
    }
    
    var numMicroSectors = -1
    var numVertex32Groups = -1
    var numNanoSectors = -1
    var finalVertexCount = -1
    
    enum NanoSector512thLayer: UInt16, MTLBufferLayer {
        case counts512th
        case offsets64
        case offsets512th
        
        static let bufferLabel = "Fourth Scene Sorter Nano Sector 512th Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .counts512th:  return capacity << 9 * MemoryLayout<UInt8>.stride
            case .offsets64:    return capacity >> 6 * MemoryLayout<UInt32>.stride
            case .offsets512th: return capacity << 9 * MemoryLayout<UInt16>.stride
            }
        }
    }
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case inclusions32nd
        case counts4th
        case countsIndividual
        case counts4
        case counts16
        case counts64
        
        case numNanoSectors4th
        case numNanoSectorsIndividual
        case numNanoSectors4
        case numNanoSectors16
        case numNanoSectors64
        
        case offsets16
        case offsets4
        case offsetsIndividual
        case offsets4th
        
        case nanoSectorOffsets64
        case nanoSectorOffsets16
        case nanoSectorOffsets4
        case nanoSectorOffsetsIndividual
        case nanoSectorOffsets4th
        
        static let bufferLabel = "Fourth Scene Sorter Bridge Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .inclusions32nd:              return capacity << 5 * MemoryLayout<UInt16>.stride
            case .counts4th:                   return capacity << 2 * MemoryLayout<UInt16>.stride
            case .countsIndividual:            return capacity      * MemoryLayout<UInt16>.stride
            case .counts4:                     return capacity >> 2 * MemoryLayout<UInt16>.stride
            case .counts16:                    return capacity >> 4 * MemoryLayout<UInt16>.stride
            case .counts64:                    return capacity >> 6 * MemoryLayout<UInt16>.stride
            
            case .numNanoSectors4th:           return capacity << 2 * MemoryLayout<UInt16>.stride
            case .numNanoSectorsIndividual:    return capacity      * MemoryLayout<UInt16>.stride
            case .numNanoSectors4:             return capacity >> 2 * MemoryLayout<UInt16>.stride
            case .numNanoSectors16:            return capacity >> 4 * MemoryLayout<UInt16>.stride
            case .numNanoSectors64:            return capacity >> 6 * MemoryLayout<UInt16>.stride
            
            case .offsets16:                   return capacity >> 4 * MemoryLayout<UInt16>.stride
            case .offsets4:                    return capacity >> 2 * MemoryLayout<UInt16>.stride
            case .offsetsIndividual:           return capacity      * MemoryLayout<UInt16>.stride
            case .offsets4th:                  return capacity << 2 * MemoryLayout<UInt16>.stride
            
            case .nanoSectorOffsets64:         return capacity >> 6 * MemoryLayout<UInt32>.stride
            case .nanoSectorOffsets16:         return capacity >> 4 * MemoryLayout<UInt16>.stride
            case .nanoSectorOffsets4:          return capacity >> 2 * MemoryLayout<UInt16>.stride
            case .nanoSectorOffsetsIndividual: return capacity      * MemoryLayout<UInt16>.stride
            case .nanoSectorOffsets4th:        return capacity << 2 * MemoryLayout<UInt16>.stride
            }
        }
    }
    
    var nanoSector512thBuffer: MTLLayeredBuffer<NanoSector512thLayer>
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    
    var destinationVertexBuffer: MTLBuffer
    var mappingsFinalBuffer: MTLBuffer
    
    var prepareMarkNanoSectorsPipelineState: MTLComputePipelineState
    var markNanoSectorsPipelineState: MTLComputePipelineState
    var poolMicroSector4thCountsPipelineState: MTLComputePipelineState
    var poolMicroSectorIndividualCountsPipelineState: MTLComputePipelineState
    var poolMicroSector4to16CountsPipelineState: MTLComputePipelineState
    var scanMicroSectors64PipelineState: MTLComputePipelineState
    
    var markMicroSector16to4OffsetsPipelineState: MTLComputePipelineState
    var markMicroSectorIndividualOffsetsPipelineState: MTLComputePipelineState
    var markMicroSector4thOffsetsPipelineState: MTLComputePipelineState
    var fillNanoSectorsPipelineState: MTLComputePipelineState
    
    init(sceneSorter: SceneSorter, library: MTLLibrary) {
        self.sceneSorter = sceneSorter
        let device = sceneSorter.device
        
        let microSectorCapacity = 512
        let nanoSectorCapacity = 32768
        let destinationVertexCapacity = 131072
        
        nanoSector512thBuffer = device.makeLayeredBuffer(capacity: microSectorCapacity, options: .storageModeShared)
        bridgeBuffer          = device.makeLayeredBuffer(capacity: microSectorCapacity, options: .storageModeShared)
        
        let destinationVertexBufferSize = destinationVertexCapacity * MemoryLayout<simd_ushort3>.stride
        destinationVertexBuffer = device.makeBuffer(length: destinationVertexBufferSize, options: .storageModePrivate)!
        destinationVertexBuffer.optLabel = "Fourth Scene Sorter Destination Vertex Buffer"
        
        let mappingsFinalBufferSize = nanoSectorCapacity * MemoryLayout<UInt32>.stride
        mappingsFinalBuffer = device.makeBuffer(length: mappingsFinalBufferSize, options: .storageModePrivate)!
        mappingsFinalBuffer.optLabel = "Fourth Scene Sorter Mappings Final Buffer"
        
        prepareMarkNanoSectorsPipelineState          = library.makeComputePipeline(Self.self, name: "prepareMarkNanoSectors")
        markNanoSectorsPipelineState                 = library.makeComputePipeline(Self.self, name: "markNanoSectors")
        poolMicroSector4thCountsPipelineState        = library.makeComputePipeline(Self.self, name: "poolMicroSector4thCounts")
        poolMicroSectorIndividualCountsPipelineState = library.makeComputePipeline(Self.self, name: "poolMicroSectorIndividualCounts")
        poolMicroSector4to16CountsPipelineState      = library.makeComputePipeline(Self.self, name: "poolMicroSector4to16Counts")
        scanMicroSectors64PipelineState              = library.makeComputePipeline(Self.self, name: "scanMicroSectors64")
        
        markMicroSector16to4OffsetsPipelineState      = library.makeComputePipeline(Self.self, name: "markMicroSector16to4Offsets")
        markMicroSectorIndividualOffsetsPipelineState = library.makeComputePipeline(Self.self, name: "markMicroSectorIndividualOffsets")
        markMicroSector4thOffsetsPipelineState        = library.makeComputePipeline(Self.self, name: "markMicroSector4thOffsets")
        fillNanoSectorsPipelineState                  = library.makeComputePipeline(Self.self, name: "fillNanoSectors")
    }
}

extension FourthSceneSorter: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case microSector
        case initialVertex
        case finalVertex
        case nanoSector
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .microSector:   ensureMicroSectorCapacity(capacity: newCapacity)
        case .initialVertex: vertexDataBuffer.ensureCapacity(device: device, capacity: newCapacity >> 1)
        case .finalVertex:   ensureFinalVertexCapacity(capacity: newCapacity)
        case .nanoSector:    ensureNanoSectorCapacity(capacity: newCapacity)
        }
    }
    
    private func ensureMicroSectorCapacity(capacity: Int) {
        nanoSector512thBuffer.ensureCapacity(device: device, capacity: capacity)
        bridgeBuffer         .ensureCapacity(device: device, capacity: capacity)
    }
    
    private func ensureFinalVertexCapacity(capacity: Int) {
        let destinationVertexBufferSize = capacity * MemoryLayout<simd_ushort3>.stride
        if destinationVertexBuffer.length < destinationVertexBufferSize {
            destinationVertexBuffer = device.makeBuffer(length: destinationVertexBufferSize, options: .storageModePrivate)!
            destinationVertexBuffer.optLabel = "Fourth Scene Sorter Destination Vertex Buffer"
        }
    }
    
    private func ensureNanoSectorCapacity(capacity: Int) {
        let mappingsFinalBufferSize = capacity * MemoryLayout<UInt32>.stride
        if mappingsFinalBuffer.length < mappingsFinalBufferSize {
            mappingsFinalBuffer = device.makeBuffer(length: mappingsFinalBufferSize, options: .storageModePrivate)!
            mappingsFinalBuffer.optLabel = "Fourth Scene Sorter Mappings Final Buffer"
        }
    }
    
}

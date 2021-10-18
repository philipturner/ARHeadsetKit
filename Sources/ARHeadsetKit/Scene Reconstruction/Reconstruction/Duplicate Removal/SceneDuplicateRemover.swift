//
//  SceneDuplicateRemover.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

final class SceneDuplicateRemover: DelegateSceneRenderer {
    unowned let sceneRenderer: SceneRenderer
    var thirdSceneSorter: ThirdSceneSorter { sceneSorter.thirdSceneSorter }
    var fourthSceneSorter: FourthSceneSorter { sceneSorter.fourthSceneSorter }
    
    var initialVertexCount: Int { fourthSceneSorter.finalVertexCount }
    var preCullVertexCount: Int { sceneMeshReducer.preCullVertexCount }
    var preCullTriangleCount: Int { sceneMeshReducer.preCullTriangleCount }
    var numNanoSectors: Int { fourthSceneSorter.numNanoSectors }
    
    typealias ThirdSorterBridgeLayer = ThirdSceneSorter.BridgeLayer
    typealias ThirdSorterMicroSectorLayer = ThirdSceneSorter.MicroSectorLayer
    typealias NanoSector512thLayer = FourthSceneSorter.NanoSector512thLayer
    
    var thirdSorterBridgeBuffer: MTLLayeredBuffer<ThirdSorterBridgeLayer> { thirdSceneSorter.bridgeBuffer }
    var thirdSorterMicroSectorBuffer: MTLLayeredBuffer<ThirdSorterMicroSectorLayer> { thirdSceneSorter.microSectorBuffer }
    var nanoSector512thBuffer: MTLLayeredBuffer<NanoSector512thLayer> { fourthSceneSorter.nanoSector512thBuffer }
    
    var sourceIDBuffer: MTLBuffer { fourthSceneSorter.destinationVertexBuffer }
    var mappingsFinalBuffer: MTLBuffer { fourthSceneSorter.mappingsFinalBuffer }
    
    var reducedVertexBuffer: MTLBuffer {
        get { sceneMeshReducer.pendingReducedVertexBuffer }
        set { sceneMeshReducer.pendingReducedVertexBuffer = newValue }
    }
    var reducedNormalBuffer: MTLBuffer {
        get { sceneMeshReducer.pendingReducedNormalBuffer }
        set { sceneMeshReducer.pendingReducedNormalBuffer = newValue }
    }
    var reducedIndexBuffer: MTLBuffer {
        get { sceneMeshReducer.pendingReducedIndexBuffer }
        set { sceneMeshReducer.pendingReducedIndexBuffer = newValue }
    }
    
    enum VertexMapLayer: UInt16, MTLBufferLayer {
        case mapCounts
        case maps
        
        static let bufferLabel = "Scene Duplicate Remover Vertex Map Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .mapCounts: return capacity * MemoryLayout<UInt8>.stride
            case .maps:      return capacity * 8 * MemoryLayout<UInt32>.stride
            }
        }
    }
    
    enum VertexDataLayer: UInt16, MTLBufferLayer {
        case vertexInclusionMark
        case nanoSectorMappings
        
        static let bufferLabel = "Scene Duplicate Remover Vertex Data Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .vertexInclusionMark: return capacity * MemoryLayout<Bool>.stride
            case .nanoSectorMappings:  return capacity * MemoryLayout<UInt32>.stride
            }
        }
    }
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case alternativeID
        case nanoSectorID
        
        case counts4
        case counts16
        case counts64
        case counts512
        case counts4096
        
        case offsets4096
        case offsets512
        case offsets64
        case offsets16
        case offsets4
        
        case numGeometryElements
        
        static let bufferLabel = "Scene Duplicate Remover Bridge Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .alternativeID:       return capacity       * MemoryLayout<UInt32>.stride
            case .nanoSectorID:        return capacity       * MemoryLayout<UInt32>.stride
            
            case .counts4:             return capacity >>  2 * MemoryLayout<UInt8>.stride
            case .counts16:            return capacity >>  4 * MemoryLayout<UInt8>.stride
            case .counts64:            return capacity >>  6 * MemoryLayout<UInt8>.stride
            case .counts512:           return capacity >>  9 * MemoryLayout<UInt16>.stride
            case .counts4096:          return capacity >> 12 * MemoryLayout<UInt16>.stride
            
            case .offsets4096:         return capacity >> 12 * MemoryLayout<UInt32>.stride
            case .offsets512:          return capacity >>  9 * MemoryLayout<UInt16>.stride
            case .offsets64:           return capacity >>  6 * MemoryLayout<UInt16>.stride
            case .offsets16:           return capacity >>  4 * MemoryLayout<UInt16>.stride
            case .offsets4:            return capacity >>  2 * MemoryLayout<UInt16>.stride
            
            case .numGeometryElements: return 3 * MemoryLayout<UInt32>.stride
            }
        }
    }
    
    var vertexMapBuffer: MTLLayeredBuffer<VertexMapLayer>
    var vertexDataBuffer: MTLLayeredBuffer<VertexDataLayer>
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    
    var triangleInclusionMarkBuffer: MTLBuffer
    
    var finalVertexBuffer: MTLBuffer
    var finalNormalBuffer: MTLBuffer
    var finalIndexBuffer: MTLBuffer
    
    var findDuplicateVerticesPipelineState: MTLComputePipelineState
    var markOriginalVertexOffsets4PipelineState: MTLComputePipelineState
    
    var removeDuplicateGeometryPipelineState: MTLComputePipelineState
    var combineDuplicateVerticesPipelineState: MTLComputePipelineState
    var condenseIncludedTrianglesPipelineState: MTLComputePipelineState
    
    init(sceneRenderer: SceneRenderer, library: MTLLibrary) {
        self.sceneRenderer = sceneRenderer
        let device = sceneRenderer.device
        
        let vertexCapacity = 32768
        let triangleCapacity = 65536
        
        vertexMapBuffer  = device.makeLayeredBuffer(capacity: vertexCapacity)
        vertexDataBuffer = device.makeLayeredBuffer(capacity: vertexCapacity)
        bridgeBuffer     = device.makeLayeredBuffer(capacity: triangleCapacity, options: .storageModeShared)
        
        let triangleInclusionMarkBufferSize = triangleCapacity * MemoryLayout<Bool>.stride
        triangleInclusionMarkBuffer = device.makeBuffer(length: triangleInclusionMarkBufferSize, options: .storageModePrivate)!
        triangleInclusionMarkBuffer.optLabel = "Scene Duplicate Remover Triangle Inclusion Mark Buffer"
        
        
        
        let finalVertexBufferSize = vertexCapacity * MemoryLayout<simd_float3>.stride
        finalVertexBuffer = device.makeBuffer(length: finalVertexBufferSize, options: .storageModePrivate)!
        finalVertexBuffer.optLabel = "Scene Duplicate Remover Final Vertex Buffer"
        
        let finalNormalBufferSize = vertexCapacity * MemoryLayout<simd_half3>.stride
        finalNormalBuffer = device.makeBuffer(length: finalNormalBufferSize, options: .storageModePrivate)!
        finalNormalBuffer.optLabel = "Scene Duplicate Remover Final Normal Buffer"
        
        let finalIndexBufferSize = triangleCapacity * MemoryLayout<simd_uint3>.stride
        finalIndexBuffer = device.makeBuffer(length: finalIndexBufferSize, options: .storageModePrivate)!
        finalIndexBuffer.optLabel = "Scene Duplicate Remover Final Index Buffer"
        
        
        
        findDuplicateVerticesPipelineState      = library.makeComputePipeline(Self.self, name: "findDuplicateVertices")
        markOriginalVertexOffsets4PipelineState = library.makeComputePipeline(Self.self, name: "markOriginalVertexOffsets4")
        
        removeDuplicateGeometryPipelineState   = library.makeComputePipeline(Self.self, name: "removeDuplicateGeometry")
        combineDuplicateVerticesPipelineState  = library.makeComputePipeline(Self.self, name: "combineDuplicateVertices")
        condenseIncludedTrianglesPipelineState = library.makeComputePipeline(Self.self, name: "condenseIncludedTriangles")
    }
}

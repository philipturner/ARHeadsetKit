//
//  SceneCuller.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

final class SceneCuller: DelegateSceneRenderer {
    unowned let sceneRenderer: SceneRenderer
    
    var preCullVertexCount: Int { sceneRenderer.preCullVertexCount }
    var preCullTriangleCount: Int { sceneRenderer.preCullTriangleCount }
    var preCullVertexCountOffset: Int { sceneRenderer.preCullVertexCountOffset }
    var preCullTriangleCountOffset: Int { sceneRenderer.preCullTriangleCountOffset }
    
    var renderTriangleIDBuffer: MTLBuffer { sceneRenderer.triangleIDBuffer }
    var occlusionTriangleIDBuffer: MTLBuffer { sceneOcclusionTester.triangleIDBuffer }
    
    typealias UniformLayer = SceneRenderer.UniformLayer
    typealias VertexLayer = SceneRenderer.VertexLayer
    typealias SectorIDLayer = SceneMeshReducer.SectorIDLayer
    
    var uniformBuffer: MTLLayeredBuffer<UniformLayer> { sceneRenderer.uniformBuffer }
    var vertexBuffer: MTLLayeredBuffer<VertexLayer> { sceneRenderer.vertexBuffer }
    var sectorIDBuffer: MTLLayeredBuffer<SectorIDLayer> { sceneMeshReducer.currentSectorIDBuffer }
    
    enum VertexDataLayer: UInt16, MTLBufferLayer {
        case inclusionData
        case mark
        case inclusions8
        
        case renderOffset
        case occlusionOffset
        
        static let bufferLabel = "Scene Culler Vertex Data Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .inclusionData:   return capacity * MemoryLayout<simd_uchar2>.stride
            case .mark:            return capacity * MemoryLayout<simd_bool2>.stride
            case .inclusions8:     return capacity >> 3 * MemoryLayout<simd_ushort2>.stride
            
            case .renderOffset:    return capacity * MemoryLayout<UInt32>.stride
            case .occlusionOffset: return capacity * MemoryLayout<UInt32>.stride
            }
        }
    }
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case triangleInclusions8
        
        case counts8
        case counts32
        case counts128
        case counts512
        case counts2048
        case counts8192
        
        case offsets8192
        case offsets2048
        case offsets512
        case offsets128
        case offsets32
        case offsets8
        
        static let bufferLabel = "Scene Culler Bridge Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .triangleInclusions8: return capacity >> 3 * MemoryLayout<simd_ushort2>.stride
                
            case .counts8:             return capacity >>  3 * MemoryLayout<simd_uchar4>.stride
            case .counts32:            return capacity >>  5 * MemoryLayout<simd_uchar4>.stride
            case .counts128:           return capacity >>  7 * MemoryLayout<simd_uchar4>.stride
            case .counts512:           return capacity >>  9 * MemoryLayout<simd_ushort4>.stride
            case .counts2048:          return capacity >> 11 * MemoryLayout<simd_ushort4>.stride
            case .counts8192:          return capacity >> 13 * MemoryLayout<simd_ushort4>.stride
            
            case .offsets8192:         return capacity >> 13 * MemoryLayout<simd_uint4>.stride
            case .offsets2048:         return capacity >> 11 * MemoryLayout<simd_uint4>.stride
            case .offsets512:          return capacity >>  9 * MemoryLayout<simd_uint4>.stride
            case .offsets128:          return capacity >>  7 * MemoryLayout<simd_uint4>.stride
            case .offsets32:           return capacity >>  5 * MemoryLayout<simd_uint4>.stride
            case .offsets8:            return capacity >>  3 * MemoryLayout<simd_uint4>.stride
            }
        }
    }
    
    enum SmallSectorLayer: UInt16, MTLBufferLayer {
        case inclusions
        
        static let bufferLabel = "Scene Culler Small Sector Inclusions buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .inclusions: return MainRenderer.numRenderBuffers * capacity * MemoryLayout<Bool>.stride
            }
        }
    }
    
    var vertexDataBuffer: MTLLayeredBuffer<VertexDataLayer>
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    var smallSectorBuffer: MTLLayeredBuffer<SmallSectorLayer>
    
    var smallSectorBufferOffset: Int { renderIndex * smallSectorBuffer.capacity * MemoryLayout<Bool>.stride }
    var octreeNodeCenters: [simd_float3]!
    
    var markVertexCulls_8bitPipelineState: MTLComputePipelineState
    var markVertexCulls_16bitPipelineState: MTLComputePipelineState
    var markTriangleCulls_8bitPipelineState: MTLComputePipelineState
    var markTriangleCulls_16bitPipelineState: MTLComputePipelineState
    
    var countCullMarks8PipelineState: MTLComputePipelineState
    var countCullMarks32to128PipelineState: MTLComputePipelineState
    var countCullMarks512PipelineState: MTLComputePipelineState
    var countCullMarks2048to8192PipelineState: MTLComputePipelineState
    
    var scanSceneCullsPipelineState: MTLComputePipelineState
    var markCullOffsets8192to2048PipelineState: MTLComputePipelineState
    var markCullOffsets512to32PipelineState: MTLComputePipelineState
    
    var condenseVerticesPipelineState: MTLComputePipelineState
    var condenseVRVerticesPipelineState: MTLComputePipelineState
    var condenseTrianglesPipelineState: MTLComputePipelineState
    var condenseTrianglesForColorUpdatePipelineState: MTLComputePipelineState
    
    init(sceneRenderer: SceneRenderer, library: MTLLibrary) {
        self.sceneRenderer = sceneRenderer
        let device = sceneRenderer.device
        
        let sectorCapacity = 16
        let vertexCapacity = 32768
        let triangleCapacity = 65536
        
        vertexDataBuffer  = device.makeLayeredBuffer(capacity: vertexCapacity)
        bridgeBuffer      = device.makeLayeredBuffer(capacity: triangleCapacity)
        smallSectorBuffer = device.makeLayeredBuffer(capacity: sectorCapacity, options: .storageModeShared)
        
        
        
        markVertexCulls_8bitPipelineState    = library.makeComputePipeline(Self.self, name: "markVertexCulls_8bit")
        markVertexCulls_16bitPipelineState   = library.makeComputePipeline(Self.self, name: "markVertexCulls_16bit")
        markTriangleCulls_8bitPipelineState  = library.makeComputePipeline(Self.self, name: "markTriangleCulls_8bit")
        markTriangleCulls_16bitPipelineState = library.makeComputePipeline(Self.self, name: "markTriangleCulls_16bit")
        
        countCullMarks8PipelineState          = library.makeComputePipeline(Self.self, name: "countCullMarks8")
        countCullMarks32to128PipelineState    = library.makeComputePipeline(Self.self, name: "countCullMarks32to128")
        countCullMarks512PipelineState        = library.makeComputePipeline(Self.self, name: "countCullMarks512")
        countCullMarks2048to8192PipelineState = library.makeComputePipeline(Self.self, name: "countCullMarks2048to8192")
        
        scanSceneCullsPipelineState            = library.makeComputePipeline(Self.self, name: "scanSceneCulls")
        markCullOffsets8192to2048PipelineState = library.makeComputePipeline(Self.self, name: "markCullOffsets8192to2048")
        markCullOffsets512to32PipelineState    = library.makeComputePipeline(Self.self, name: "markCullOffsets512to32")
        
        condenseVerticesPipelineState                = library.makeComputePipeline(Self.self, name: "condenseVertices")
        condenseVRVerticesPipelineState              = library.makeComputePipeline(Self.self, name: "condenseVRVertices")
        condenseTrianglesPipelineState               = library.makeComputePipeline(Self.self, name: "condenseTriangles")
        condenseTrianglesForColorUpdatePipelineState = library.makeComputePipeline(Self.self, name: "condenseTrianglesForColorUpdate")
    }
}

extension SceneCuller: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case sector
        case vertex
        case triangle
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .sector:   smallSectorBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .vertex:   vertexDataBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .triangle: bridgeBuffer.ensureCapacity(device: device, capacity: newCapacity)
        }
    }
    
}

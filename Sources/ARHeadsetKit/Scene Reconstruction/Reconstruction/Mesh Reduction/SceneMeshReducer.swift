//
//  SceneMeshReducer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import ARKit

final class SceneMeshReducer: DelegateSceneRenderer {
    unowned let sceneRenderer: SceneRenderer
    
    var meshUpdateCounter: Int = 100_000_000
    var shouldUpdateMesh = false
    
    var meshUpdateRate: Int {
        if SceneRenderer.profilingSceneReconstruction {
            return 0
        }
        
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return 18 - 2
        case .fair:     return 36 - 2
        case .serious:  return 72
        case .critical: return 100_000_000
        @unknown default: fatalError("This thermal state is not possible!")
        }
    }
    
    var meshToWorldTransform = simd_float4x4(1)
    var submeshes: [ARMeshAnchor] = []
    
    typealias SmallSectorHashLayer = SceneMeshMatcher.SmallSectorLayer
    var smallSectorHashBuffer: MTLLayeredBuffer<SmallSectorHashLayer> { sceneMeshMatcher.newSmallSectorBuffer }
    
    enum UniformLayer: UInt16, MTLBufferLayer {
        case numVertices
        case numTriangles
        case meshTranslation
        
        static let bufferLabel = "Scene Mesh Reducer Uniform Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .numVertices:     return capacity * MemoryLayout<UInt32>.stride
            case .numTriangles:    return capacity * MemoryLayout<UInt32>.stride
            case .meshTranslation: return capacity * MemoryLayout<simd_float3>.stride
            }
        }
    }
    
    enum BridgeLayer: UInt16, MTLBufferLayer {
        case vertexMark
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
        case vertexOffset
        
        static let bufferLabel = "Scene Mesh Reducer Bridge Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .vertexMark:   return capacity       * MemoryLayout<UInt8>.stride
            case .counts4:      return capacity >>  2 * MemoryLayout<UInt8>.stride
            case .counts16:     return capacity >>  4 * MemoryLayout<UInt8>.stride
            case .counts64:     return capacity >>  6 * MemoryLayout<UInt8>.stride
            case .counts512:    return capacity >>  9 * MemoryLayout<UInt16>.stride
            case .counts4096:   return capacity >> 12 * MemoryLayout<UInt16>.stride
                
            case .offsets4096:  return capacity >> 12 * MemoryLayout<UInt32>.stride
            case .offsets512:   return capacity >>  9 * MemoryLayout<UInt32>.stride
            case .offsets64:    return capacity >>  6 * MemoryLayout<UInt32>.stride
            case .offsets16:    return capacity >>  4 * MemoryLayout<UInt32>.stride
            case .offsets4:     return capacity >>  2 * MemoryLayout<UInt32>.stride
            case .vertexOffset: return capacity       * MemoryLayout<UInt32>.stride
            }
        }
    }
    
    enum SectorIDLayer: UInt16, MTLBufferLayer {
        case triangleGroupMask
        case triangleGroup
        
        case vertexGroupMask
        case vertexGroup
        
        static let bufferLabel = "Scene Mesh Reducer Sector ID Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .triangleGroupMask: return capacity >> 6 * MemoryLayout<UInt8>.stride
            case .triangleGroup:     return capacity >> 3 * MemoryLayout<UInt8>.stride
                
            case .vertexGroupMask:   return capacity >> 6 * MemoryLayout<UInt8>.stride
            case .vertexGroup:       return capacity >> 3 * MemoryLayout<UInt8>.stride
            }
        }
    }
    
    var uniformBuffer: MTLLayeredBuffer<UniformLayer>
    var bridgeBuffer: MTLLayeredBuffer<BridgeLayer>
    
    var currentSectorIDBuffer: MTLLayeredBuffer<SectorIDLayer>
    var pendingSectorIDBuffer: MTLLayeredBuffer<SectorIDLayer>
    var transientSectorIDBuffer: MTLBuffer
    
    var preCullVertexCount: Int!
    var preCullTriangleCount: Int!
    
    var currentReducedVertexBuffer: MTLBuffer
    var currentReducedNormalBuffer: MTLBuffer
    var currentReducedColorBuffer: MTLBuffer
    var currentReducedIndexBuffer: MTLBuffer
    
    var pendingReducedVertexBuffer: MTLBuffer
    var pendingReducedNormalBuffer: MTLBuffer
    var pendingReducedColorBuffer: MTLBuffer
    var pendingReducedIndexBuffer: MTLBuffer
    
    var markSubmeshVerticesPipelineState: MTLComputePipelineState
    var countSubmeshVertices4to64PipelineState: MTLComputePipelineState
    var countSubmeshVertices512PipelineState: MTLComputePipelineState
    var scanSubmeshVertices4096PipelineState: MTLComputePipelineState
    
    var markSubmeshVertexOffsets512PipelineState: MTLComputePipelineState
    var markSubmeshVertexOffsets64to16PipelineState: MTLComputePipelineState
    var markSubmeshVertexOffsets4PipelineState: MTLComputePipelineState
    var reduceSubmeshesPipelineState: MTLComputePipelineState
    
    var slowAssignVertexSectorIDs_8bitPipelineState: MTLComputePipelineState
    var fastAssignVertexSectorIDs_8bitPipelineState: MTLComputePipelineState
    var assignVertexSectorIDs_16bitPipelineState: MTLComputePipelineState
    
    var slowAssignTriangleSectorIDs_8bitPipelineState: MTLComputePipelineState
    var fastAssignTriangleSectorIDs_8bitPipelineState: MTLComputePipelineState
    var assignTriangleSectorIDs_16bitPipelineState: MTLComputePipelineState
    
    var poolVertexGroupSectorIDs_8bitPipelineState: MTLComputePipelineState
    var poolVertexGroupSectorIDs_16bitPipelineState: MTLComputePipelineState
    var poolTriangleGroupSectorIDs_8bitPipelineState: MTLComputePipelineState
    var poolTriangleGroupSectorIDs_16bitPipelineState: MTLComputePipelineState
    
    init(sceneRenderer: SceneRenderer, library: MTLLibrary) {
        self.sceneRenderer = sceneRenderer
        let device = sceneRenderer.device
        
        let meshCapacity = 16
        let vertexCapacity = 32768
        let triangleCapacity = 65536
        
        uniformBuffer = device.makeLayeredBuffer(capacity: meshCapacity,   options: .storageModeShared)
        bridgeBuffer  = device.makeLayeredBuffer(capacity: vertexCapacity, options: .storageModeShared)
        
        currentSectorIDBuffer = device.makeLayeredBuffer(capacity: triangleCapacity)
        pendingSectorIDBuffer = device.makeLayeredBuffer(capacity: triangleCapacity)
        currentSectorIDBuffer.optLabel = "Scene Mesh Reducer Sector ID Buffer (Not Used Yet)"
        pendingSectorIDBuffer.optLabel = "Scene Mesh Reducer Sector ID Buffer (Pending)"
        
        let transientSectorIDBufferSize = triangleCapacity * MemoryLayout<UInt8>.stride
        transientSectorIDBuffer = device.makeBuffer(length: transientSectorIDBufferSize, options: .storageModePrivate)!
        transientSectorIDBuffer.optLabel = "Scene Mesh Reducer Transient Sector ID Buffer"
        
        
        
        let reducedVertexBufferSize = vertexCapacity * MemoryLayout<simd_float3>.stride
        currentReducedVertexBuffer = device.makeBuffer(length: reducedVertexBufferSize, options: .storageModePrivate)!
        pendingReducedVertexBuffer = device.makeBuffer(length: reducedVertexBufferSize, options: .storageModePrivate)!
        currentReducedVertexBuffer.optLabel = "Scene Reduced Vertex Buffer (Not Used Yet)"
        pendingReducedVertexBuffer.optLabel = "Scene Reduced Vertex Buffer (Pending)"
        
        let reducedNormalBufferSize = vertexCapacity * MemoryLayout<simd_half3>.stride
        currentReducedNormalBuffer = device.makeBuffer(length: reducedNormalBufferSize, options: .storageModePrivate)!
        pendingReducedNormalBuffer = device.makeBuffer(length: reducedNormalBufferSize, options: .storageModePrivate)!
        currentReducedNormalBuffer.optLabel = "Scene Reduced Normal Buffer (Not Used Yet)"
        pendingReducedNormalBuffer.optLabel = "Scene Reduced Normal Buffer (Pending)"
        
        let reducedColorBufferSize = triangleCapacity * MemoryLayout<simd_uint4>.stride
        currentReducedColorBuffer = device.makeBuffer(length: reducedColorBufferSize, options: .storageModePrivate)!
        pendingReducedColorBuffer = device.makeBuffer(length: reducedColorBufferSize, options: .storageModePrivate)!
        currentReducedColorBuffer.optLabel = "Scene Reduced Color Buffer (Not Used Yet)"
        pendingReducedColorBuffer.optLabel = "Scene Reduced Color Buffer (Pending)"
        
        let reducedIndexBufferSize = triangleCapacity * MemoryLayout<simd_uint3>.stride
        currentReducedIndexBuffer = device.makeBuffer(length: reducedIndexBufferSize, options: .storageModePrivate)!
        pendingReducedIndexBuffer = device.makeBuffer(length: reducedIndexBufferSize, options: .storageModePrivate)!
        currentReducedIndexBuffer.optLabel = "Scene Reduced Index Buffer (Not Used Yet)"
        pendingReducedIndexBuffer.optLabel = "Scene Reduced Index Buffer (Pending)"
        
        
        
        markSubmeshVerticesPipelineState       = library.makeComputePipeline(Self.self, name: "markSubmeshVertices")
        countSubmeshVertices4to64PipelineState = library.makeComputePipeline(Self.self, name: "countSubmeshVertices4to64")
        countSubmeshVertices512PipelineState   = library.makeComputePipeline(Self.self, name: "countSubmeshVertices512")
        scanSubmeshVertices4096PipelineState   = library.makeComputePipeline(Self.self, name: "scanSubmeshVertices4096")
        
        markSubmeshVertexOffsets512PipelineState    = library.makeComputePipeline(Self.self, name: "markSubmeshVertexOffsets512")
        markSubmeshVertexOffsets64to16PipelineState = library.makeComputePipeline(Self.self, name: "markSubmeshVertexOffsets64to16")
        markSubmeshVertexOffsets4PipelineState      = library.makeComputePipeline(Self.self, name: "markSubmeshVertexOffsets4")
        reduceSubmeshesPipelineState                = library.makeComputePipeline(Self.self, name: "reduceSubmeshes_noRotation")
        
        
        
        let computePipelineDescriptor = MTLComputePipelineDescriptor()
        computePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
        
        let assignVertexSectorIDs_8bitFunction = library.makeFunction(name: "assignVertexSectorIDs_8bit")!
        slowAssignVertexSectorIDs_8bitPipelineState = library.makeComputePipeline(Self.self,
                                                                                  name: "Assign Vertex Sector IDs (8-bit, Slow)",
                                                                                  function: assignVertexSectorIDs_8bitFunction)
        
        computePipelineDescriptor.computeFunction = assignVertexSectorIDs_8bitFunction
        computePipelineDescriptor.optLabel = "Scene Mesh Reducer Assign Vertex Sector IDs (8-bit, Fast) Pipeline"
        fastAssignVertexSectorIDs_8bitPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        computePipelineDescriptor.computeFunction =  library.makeFunction(name: "assignVertexSectorIDs_16bit")!
        computePipelineDescriptor.optLabel = "Scene Mesh Reducer Assign Vertex Sector IDs (16-bit) Pipeline"
        assignVertexSectorIDs_16bitPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        
        
        let assignTriangleSectorIDs_8bitFunction = library.makeFunction(name: "assignTriangleSectorIDs_8bit")!
        slowAssignTriangleSectorIDs_8bitPipelineState = library.makeComputePipeline(Self.self,
                                                                                    name: "Assign Triangle Sector IDs (8-bit, Slow)",
                                                                                    function: assignTriangleSectorIDs_8bitFunction)
        
        computePipelineDescriptor.computeFunction = assignTriangleSectorIDs_8bitFunction
        computePipelineDescriptor.optLabel = "Scene Mesh Reducer Assign Triangle Sector IDs (8-bit, Fast) Pipeline"
        fastAssignTriangleSectorIDs_8bitPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        computePipelineDescriptor.computeFunction = library.makeFunction(name: "assignTriangleSectorIDs_16bit")!
        computePipelineDescriptor.optLabel = "Scene Mesh Reducer Assign Triangle Sector IDs (16-bit) Pipeline"
        assignTriangleSectorIDs_16bitPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
        
        
        
        poolVertexGroupSectorIDs_8bitPipelineState    = library.makeComputePipeline(Self.self, name: "poolVertexGroupSectorIDs_8bit")
        poolVertexGroupSectorIDs_16bitPipelineState   = library.makeComputePipeline(Self.self, name: "poolVertexGroupSectorIDs_16bit")
        poolTriangleGroupSectorIDs_8bitPipelineState  = library.makeComputePipeline(Self.self, name: "poolTriangleGroupSectorIDs_8bit")
        poolTriangleGroupSectorIDs_16bitPipelineState = library.makeComputePipeline(Self.self, name: "poolTriangleGroupSectorIDs_16bit")
    }
    
}

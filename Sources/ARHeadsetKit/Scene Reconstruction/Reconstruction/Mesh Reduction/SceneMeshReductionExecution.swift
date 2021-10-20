//
//  SceneMeshReductionExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import ARKit

fileprivate extension ARMeshAnchor {
    var vertexBuffer: MTLBuffer { geometry.vertices.buffer }
    var normalBuffer: MTLBuffer { geometry.normals.buffer }
    var indexBuffer: MTLBuffer { geometry.faces.buffer }
}

extension SceneMeshReducer {
    
    func reduceMeshes() {
        debugLabel {
            for i in 0..<submeshes.count {
                submeshes[i].vertexBuffer.label = "Submesh \(i) Vertex Buffer"
                submeshes[i].normalBuffer.label = "Submesh \(i) Normal Buffer"
                submeshes[i].indexBuffer.label  = "Submesh \(i) Index Buffer"
            }
        }
        
        let vertexCounts = submeshes.map{ $0.vertexBuffer.length / MemoryLayout<simd_packed_float3>.stride }
        let triangleCounts = submeshes.map{ $0.indexBuffer.length / MemoryLayout<simd_packed_uint3>.stride }
        
        let preFilterVertexCount = vertexCounts.reduce(0, +)
        preCullTriangleCount = triangleCounts.reduce(0, +)
        
        ensureBufferCapacity(type: .mesh,     capacity: submeshes.count)
        ensureBufferCapacity(type: .vertex,   capacity: preFilterVertexCount)
        ensureBufferCapacity(type: .triangle, capacity: preCullTriangleCount)
        
        let commandBuffer1 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer1.optLabel = "Scene Mesh Reduction Command Buffer 1"
        
        let blitEncoder = commandBuffer1.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Scene Mesh Reduction - Clear Vertex Mark Buffer"
        
        let expandedVertexCount = ~4095 & (preFilterVertexCount + 4095)
        let fillSize = expandedVertexCount * MemoryLayout<UInt8>.stride
        blitEncoder.fill(buffer: bridgeBuffer, layer: .vertexMark, range: 0..<fillSize, value: 0)
        
        blitEncoder.endEncoding()
        
        
        
        var computeEncoder = commandBuffer1.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Scene Mesh Reduction - Compute Pass 1"
        
        computeEncoder.pushOptDebugGroup("Mark Submesh Vertices")
        
        computeEncoder.setComputePipelineState(markSubmeshVerticesPipelineState)
        
        var vertexMarkOffset = 0
        
        for i in 0..<submeshes.count {
            computeEncoder.setBuffer(bridgeBuffer, layer: .vertexMark, offset: vertexMarkOffset, index: 0, bound: i != 0)
            computeEncoder.setBuffer(submeshes[i].indexBuffer,         offset: 0,                index: 1)
            computeEncoder.dispatchThreadgroups([ triangleCounts[i] ], threadsPerThreadgroup: 1)
            
            vertexMarkOffset += vertexCounts[i] * MemoryLayout<UInt8>.stride
        }
        
        if submeshes.count > 1 {
            computeEncoder.setBuffer(bridgeBuffer, layer: .vertexMark, offset: 0, index: 0, bound: true)
        }
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Count Submesh Vertices")
        
        computeEncoder.setComputePipelineState(countSubmeshVertices4to64PipelineState)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4, index: 1)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,  index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16, index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts64, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(countSubmeshVertices512PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts512, index: 0, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 9 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(scanSubmeshVertices4096PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4096, index: 1, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets512, index: 2)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 12 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer1.commit()
        
        
        
        let numVerticesPointer     = uniformBuffer[.numVertices].assumingMemoryBound(to: UInt32.self)
        let numTrianglesPointer    = uniformBuffer[.numTriangles].assumingMemoryBound(to: UInt32.self)
        let meshTranslationPointer = uniformBuffer[.meshTranslation].assumingMemoryBound(to: simd_float3.self)
        
        meshToWorldTransform = submeshes[0].transform.replacingTranslation(with: .zero)
        let worldToMeshTransform = meshToWorldTransform.inverseRotationTranslation
        
        for i in 0..<submeshes.count {
            numVerticesPointer[i]     = UInt32(vertexCounts[i])
            numTrianglesPointer[i]    = UInt32(triangleCounts[i])
            meshTranslationPointer[i] = simd_make_float3(worldToMeshTransform * submeshes[i].transform[3])
        }
        
        let commandBuffer2 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer2.optLabel = "Scene Mesh Reduction Command Buffer 2"
        
        computeEncoder = commandBuffer2.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Scene Mesh Reduction - Compute Pass 2"
        
        computeEncoder.pushOptDebugGroup("Mark Submesh Vertex Offsets")
        
        computeEncoder.setComputePipelineState(markSubmeshVertexOffsets512PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts64,   index: 0)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets64,  index: 1)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets512, index: 2)
        computeEncoder.dispatchThreadgroups([ (preFilterVertexCount + 511) >> 9 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markSubmeshVertexOffsets64to16PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16,  index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets16, index: 2, bound: true)
        computeEncoder.dispatchThreadgroups([ (preFilterVertexCount + 63) >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,   index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets16, index: 1, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets4,  index: 2, bound: true)
        computeEncoder.dispatchThreadgroups([ (preFilterVertexCount + 15) >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markSubmeshVertexOffsets4PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .vertexMark,   index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .vertexOffset, index: 1, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets4096,  index: 3)
        computeEncoder.dispatchThreadgroups([ (preFilterVertexCount + 3) >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Reduce Submeshes")
        
        computeEncoder.setComputePipelineState(reduceSubmeshesPipelineState)
        computeEncoder.setBuffer(pendingReducedIndexBuffer,   offset: 0, index: 8)
        computeEncoder.setBuffer(pendingReducedVertexBuffer,  offset: 0, index: 9)
        computeEncoder.setBuffer(pendingReducedNormalBuffer,  offset: 0, index: 10)
        
        var vertexOffset = 0
        var triangleOffset = 0
        
        for i in 0..<submeshes.count {
            if i > 0 {
                let vertexMarkOffset   = vertexOffset * MemoryLayout<UInt8>.stride
                let vertexOffsetOffset = vertexOffset * MemoryLayout<UInt32>.stride
                
                computeEncoder.setBuffer(bridgeBuffer,  layer: .vertexMark,   offset: vertexMarkOffset,   index: 0, bound: true)
                computeEncoder.setBuffer(bridgeBuffer,  layer: .vertexOffset, offset: vertexOffsetOffset, index: 1, bound: true)
                computeEncoder.setBufferOffset(triangleOffset * MemoryLayout<simd_uint3>.stride,          index: 8)
            }
            
            let numVerticesOffset     = i * MemoryLayout<UInt32>.stride
            let numTrianglesOffset    = i * MemoryLayout<UInt32>.stride
            let meshTranslationOffset = i * MemoryLayout<simd_float3>.stride
            
            computeEncoder.setBuffer(uniformBuffer, layer: .numVertices,     offset: numVerticesOffset,     index: 2, bound: i > 0)
            computeEncoder.setBuffer(uniformBuffer, layer: .numTriangles,    offset: numTrianglesOffset,    index: 3, bound: i > 0)
            computeEncoder.setBuffer(uniformBuffer, layer: .meshTranslation, offset: meshTranslationOffset, index: 4, bound: i > 0)
            
            let submesh = submeshes[i]
            
            computeEncoder.setBuffer(submesh.indexBuffer,  offset: 0, index: 5)
            computeEncoder.setBuffer(submesh.vertexBuffer, offset: 0, index: 6)
            computeEncoder.setBuffer(submesh.normalBuffer, offset: 0, index: 7)
            
            let vertexCount   = vertexCounts[i]
            let triangleCount = triangleCounts[i]
            
            vertexOffset   += vertexCount
            triangleOffset += triangleCount
            
            computeEncoder.dispatchThreadgroups([ max(vertexCount, triangleCount) ], threadsPerThreadgroup: 1)
        }
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        let counts4096Pointer  = bridgeBuffer[.counts4096].assumingMemoryBound(to: UInt16.self)
        let offsets4096Pointer = bridgeBuffer[.offsets4096].assumingMemoryBound(to: UInt32.self)
        
        commandBuffer1.waitUntilCompleted()
        
        
        
        do {
            var vertexOffset: UInt32 = 0
            
            for i in 0..<expandedVertexCount >> 12 {
                offsets4096Pointer[i] = vertexOffset
                vertexOffset += UInt32(counts4096Pointer[i])
            }
        }
        
        commandBuffer2.commit()
        
        preCullVertexCount = Int(vertexOffset)
    }
    
    func prepareOptimizedCulling() {
        let numVerticesPointer = uniformBuffer[.numVertices].assumingMemoryBound(to: UInt32.self)
        numVerticesPointer.pointee = UInt32(preCullVertexCount)
        
        let numTrianglesPointer = uniformBuffer[.numTriangles].assumingMemoryBound(to: UInt32.self)
        numTrianglesPointer.pointee = UInt32(preCullTriangleCount)
        
        let doing8bitSectorIDs = sceneSorter.octreeAsArray.count <= 255
        let sectorIDBufferSize = preCullTriangleCount << (doing8bitSectorIDs ? 0 : 1)
        ensureBufferCapacity(type: .sectorID, capacity: sectorIDBufferSize)
        
        
        
        let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer.optLabel = "Prepare Optimized Culling Command Buffer"
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Prepare Optimized Culling - Clear Triangle Group Marks"
        
        let fillSize = (preCullTriangleCount + 63) >> 6
        blitEncoder.fill(buffer: pendingSectorIDBuffer, layer: .triangleGroupMask, range: 0..<fillSize, value: 0)
        blitEncoder.endEncoding()
        
        @inline(__always)
        func getThreadgroupSize(_ input: Int) -> Int {
            var output = roundUpToPowerOf2(input + 1) >> 1
            
            if output >= 64 {
                output >>= 1
            }
            
            return min(1024, output)
        }
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Prepare Optimized Culling - Compute Pass"
        
        
        
        computeEncoder.pushOptDebugGroup("Prepare Vertices")
        
        var threadgroupSize = getThreadgroupSize(preCullVertexCount)
        
        if doing8bitSectorIDs {
            computeEncoder.setComputePipelineState(threadgroupSize >= 32
                                                 ? fastAssignVertexSectorIDs_8bitPipelineState
                                                 : slowAssignVertexSectorIDs_8bitPipelineState)
        } else {
            computeEncoder.setComputePipelineState(assignVertexSectorIDs_16bitPipelineState)
        }
        computeEncoder.setBuffer(pendingReducedVertexBuffer,             offset: 0, index: 1)
        
        computeEncoder.setBuffer(smallSectorHashBuffer, layer: .numSectorsMinus1,   index: 2)
        computeEncoder.setBuffer(smallSectorHashBuffer, layer: .sortedHashes,       index: 3)
        computeEncoder.setBuffer(smallSectorHashBuffer, layer: .sortedHashMappings, index: 4)
        
        computeEncoder.setBuffer(transientSectorIDBuffer,                offset: 0, index: 5)
        computeEncoder.dispatchThreads([ preCullVertexCount ], threadsPerThreadgroup: [ threadgroupSize ])
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Prepare Vertex Groups")
        
        computeEncoder.setComputePipelineState(doing8bitSectorIDs ? poolVertexGroupSectorIDs_8bitPipelineState
                                                                  : poolVertexGroupSectorIDs_16bitPipelineState)
        computeEncoder.setBuffer(pendingSectorIDBuffer, layer: .vertexGroup,     index: 6)
        computeEncoder.setBuffer(pendingSectorIDBuffer, layer: .vertexGroupMask, index: 7)
        
        computeEncoder.setBuffer(uniformBuffer,         layer: .numVertices,     index: 8)
        computeEncoder.dispatchThreads([ (preCullVertexCount + 7) >> 3 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        
        
        
        computeEncoder.pushOptDebugGroup("Prepare Triangles")
        
        threadgroupSize = getThreadgroupSize(preCullTriangleCount)
        
        if doing8bitSectorIDs {
            computeEncoder.setComputePipelineState(threadgroupSize >= 32
                                                 ? fastAssignTriangleSectorIDs_8bitPipelineState
                                                 : slowAssignTriangleSectorIDs_8bitPipelineState)
        } else {
            computeEncoder.setComputePipelineState(assignTriangleSectorIDs_16bitPipelineState)
        }
        computeEncoder.setBuffer(pendingReducedIndexBuffer, offset: 0, index: 0)
        computeEncoder.dispatchThreads([ preCullTriangleCount ], threadsPerThreadgroup: [ threadgroupSize ])
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Prepare Triangle Groups")
        
        computeEncoder.setComputePipelineState(doing8bitSectorIDs ? poolTriangleGroupSectorIDs_8bitPipelineState
                                                                  : poolTriangleGroupSectorIDs_16bitPipelineState)
        computeEncoder.setBuffer(pendingSectorIDBuffer, layer: .triangleGroup,     index: 6, bound: true)
        computeEncoder.setBuffer(pendingSectorIDBuffer, layer: .triangleGroupMask, index: 7, bound: true)
        
        computeEncoder.setBuffer(uniformBuffer,         layer: .numTriangles,      index: 8, bound: true)
        computeEncoder.dispatchThreads([ (preCullTriangleCount + 7) >> 3 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        
        commandBuffer.waitUntilCompleted()
    }
    
}
#endif

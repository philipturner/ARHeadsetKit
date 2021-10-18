//
//  SceneDuplicateRemovalExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

extension SceneDuplicateRemover {
    
    func removeDuplicateVertices() {
        ensureBufferCapacity(type: .triangle, capacity: preCullTriangleCount)
        ensureBufferCapacity(type: .vertex,   capacity: preCullVertexCount)
        
        let commandBuffer1 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer1.optLabel = "Scene Duplicate Removal Command Buffer 1"
        
        let blitEncoder = commandBuffer1.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Scene Duplicate Removal - Clear Mark Buffers"
        
        blitEncoder.fill(buffer: triangleInclusionMarkBuffer,                   range: 0..<preCullTriangleCount, value: 1)
        blitEncoder.fill(buffer: vertexDataBuffer, layer: .vertexInclusionMark, range: 0..<preCullVertexCount,   value: 1)
        
        let expandedVertexCount = ~4095 & (preCullVertexCount + 4095)
        if expandedVertexCount > preCullVertexCount {
            let fillRange = preCullVertexCount..<expandedVertexCount
            blitEncoder.fill(buffer: vertexDataBuffer, layer: .vertexInclusionMark, range: fillRange, value: 0)
        }
        
        let expandedTriangleCount = ~4095 & (preCullTriangleCount + 4095)
        if expandedTriangleCount > preCullTriangleCount {
            blitEncoder.fill(buffer: triangleInclusionMarkBuffer, range: preCullTriangleCount..<expandedTriangleCount, value: 0)
        }
        
        let mapCountBufferSize = preCullVertexCount * MemoryLayout<UInt8>.stride
        blitEncoder.fill(buffer: vertexMapBuffer, layer: .mapCounts, range: 0..<mapCountBufferSize, value: 0)
        blitEncoder.endEncoding()
        
        
        
        var computeEncoder = commandBuffer1.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Scene Duplicate Removal - Compute Pass 1"
        
        computeEncoder.pushOptDebugGroup("Find Duplicate Vertices")
        
        computeEncoder.setComputePipelineState(findDuplicateVerticesPipelineState)
        computeEncoder.setBuffer(vertexDataBuffer,             layer: .vertexInclusionMark,              index: 0)
        computeEncoder.setBuffer(bridgeBuffer,                 layer: .alternativeID,                    index: 1)
        
        computeEncoder.setBuffer(thirdSorterBridgeBuffer,      layer: .smallSectorBounds,                index: 2)
        computeEncoder.setBuffer(thirdSorterMicroSectorBuffer, layer: .microSectorToSmallSectorMappings, index: 3)
        computeEncoder.setBuffer(thirdSorterMicroSectorBuffer, layer: .microSectorIDsInSmallSectors,     index: 4)
        computeEncoder.setBuffer(sourceIDBuffer,                                              offset: 0, index: 5)
        computeEncoder.setBuffer(reducedVertexBuffer,                                         offset: 0, index: 6)
        
        computeEncoder.setBuffer(nanoSector512thBuffer,        layer: .offsets64,                        index: 7)
        computeEncoder.setBuffer(nanoSector512thBuffer,        layer: .offsets512th,                     index: 8)
        computeEncoder.setBuffer(nanoSector512thBuffer,        layer: .counts512th,                      index: 9)
        computeEncoder.setBuffer(bridgeBuffer,                 layer: .nanoSectorID,                     index: 10)
        computeEncoder.dispatchThreadgroups([ initialVertexCount ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Count Original Vertices")
        
        computeEncoder.setComputePipelineState(sceneMeshReducer.countSubmeshVertices4to64PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,  index: 0)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16, index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts64, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(sceneMeshReducer.countSubmeshVertices512PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts512, index: 0, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 9 ], threadsPerThreadgroup: 1)
        
        let numVertex4096Groups = expandedVertexCount >> 12
        computeEncoder.setComputePipelineState(sceneMeshReducer.scanSubmeshVertices4096PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4096, index: 1, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets512, index: 2)
        computeEncoder.dispatchThreadgroups([ numVertex4096Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer1.commit()
        
        
        
        let commandBuffer2 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer2.optLabel = "Scene Duplicate Removal Command Buffer 2"
            
        computeEncoder = commandBuffer2.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Scene Duplicate Removal - Compute Pass 2"
        
        computeEncoder.pushOptDebugGroup("Mark Submesh Vertex Offsets")
        
        computeEncoder.setComputePipelineState(sceneMeshReducer.markSubmeshVertexOffsets512PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts64,   index: 0)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets64,  index: 1)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets512, index: 2)
        computeEncoder.dispatchThreadgroups([ (preCullVertexCount + 511) >> 9 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(sceneMeshReducer.markSubmeshVertexOffsets64to16PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16,  index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets16, index: 2, bound: true)
        computeEncoder.dispatchThreadgroups([ (preCullVertexCount + 63) >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,   index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets16, index: 1, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets4,  index: 2, bound: true)
        computeEncoder.dispatchThreadgroups([ (preCullVertexCount + 15) >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markOriginalVertexOffsets4PipelineState)
        computeEncoder.setBuffer(bridgeBuffer,     layer: .alternativeID,       index: 1, bound: true)
        computeEncoder.setBuffer(bridgeBuffer,     layer: .offsets4096,         index: 3)
        
        computeEncoder.setBuffer(vertexDataBuffer, layer: .nanoSectorMappings,  index: 4)
        computeEncoder.setBuffer(bridgeBuffer,     layer: .nanoSectorID,        index: 5)
        computeEncoder.setBuffer(vertexDataBuffer, layer: .vertexInclusionMark, index: 7)
        computeEncoder.dispatchThreadgroups([ (preCullVertexCount + 3) >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Remove Duplicate Geometry")
        
        computeEncoder.setComputePipelineState(removeDuplicateGeometryPipelineState)
        computeEncoder.setBuffer(triangleInclusionMarkBuffer,                        offset: 0, index: 0)
        computeEncoder.setBuffer(bridgeBuffer,          layer: .numGeometryElements, offset: 0, index: 2, bound: true)
        computeEncoder.setBuffer(bridgeBuffer,          layer: .numGeometryElements, offset: 4, index: 3, bound: true)
        computeEncoder.setBuffer(bridgeBuffer,          layer: .numGeometryElements, offset: 8, index: 4)
        
        computeEncoder.setBuffer(sourceIDBuffer,                                     offset: 0, index: 5)
        computeEncoder.setBuffer(reducedIndexBuffer,                                 offset: 0, index: 6)
        
        computeEncoder.setBuffer(mappingsFinalBuffer,                                offset: 0, index: 8)
        computeEncoder.setBuffer(nanoSector512thBuffer, layer: .offsets64,                      index: 9)
        computeEncoder.setBuffer(nanoSector512thBuffer, layer: .offsets512th,                   index: 10)
        computeEncoder.setBuffer(nanoSector512thBuffer, layer: .counts512th,                    index: 11)
        
        computeEncoder.setBuffer(vertexMapBuffer,       layer: .mapCounts,                      index: 12)
        computeEncoder.setBuffer(vertexMapBuffer,       layer: .maps,                           index: 13)
        
        let maxGeometryElementCount = max(preCullVertexCount, preCullTriangleCount, numNanoSectors)
        computeEncoder.dispatchThreadgroups([ maxGeometryElementCount ], threadsPerThreadgroup: 1)
        
        let numGeometryElementsPointer = bridgeBuffer[.numGeometryElements].assumingMemoryBound(to: UInt32.self)
        numGeometryElementsPointer[0] = UInt32(numNanoSectors)
        numGeometryElementsPointer[1] = UInt32(preCullTriangleCount)
        numGeometryElementsPointer[2] = UInt32(preCullVertexCount)
        
        
        
        computeEncoder.setComputePipelineState(combineDuplicateVerticesPipelineState)
        computeEncoder.setBuffer(reducedVertexBuffer, offset: 0, index: 2)
        computeEncoder.setBuffer(reducedNormalBuffer, offset: 0, index: 3)
        
        computeEncoder.setBuffer(finalVertexBuffer,   offset: 0, index: 4)
        computeEncoder.setBuffer(finalNormalBuffer,   offset: 0, index: 5)
        computeEncoder.dispatchThreadgroups([ preCullVertexCount ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Count Included Triangles")
        
        computeEncoder.setComputePipelineState(sceneMeshReducer.countSubmeshVertices4to64PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedTriangleCount >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,  index: 0)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedTriangleCount >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16, index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts64, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedTriangleCount >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(sceneMeshReducer.countSubmeshVertices512PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts512, index: 0, bound: true)
        computeEncoder.dispatchThreadgroups([ expandedTriangleCount >> 9 ], threadsPerThreadgroup: 1)
        
        let numTriangle4096Groups = expandedTriangleCount >> 12
        computeEncoder.setComputePipelineState(sceneMeshReducer.scanSubmeshVertices4096PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4096, index: 1, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets512, index: 2)
        computeEncoder.dispatchThreadgroups([ numTriangle4096Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        let counts4096Pointer  = bridgeBuffer[.counts4096].assumingMemoryBound(to: UInt16.self)
        let offsets4096Pointer = bridgeBuffer[.offsets4096].assumingMemoryBound(to: UInt32.self)
        
        commandBuffer1.waitUntilCompleted()
        
        var vertexOffset: UInt32 = 0
        
        for i in 0..<numVertex4096Groups {
            offsets4096Pointer[i] = vertexOffset
            vertexOffset += UInt32(counts4096Pointer[i])
        }
        
        commandBuffer2.commit()
        
        
        
        let commandBuffer3 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer3.optLabel = "Scene Duplicate Removal Command Buffer 3"
        
        computeEncoder = commandBuffer3.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Scene Duplicate Removal - Compute Pass 3"
        
        computeEncoder.pushOptDebugGroup("Mark Included Triangle Offsets")
        
        computeEncoder.setComputePipelineState(sceneMeshReducer.markSubmeshVertexOffsets512PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts64,   index: 0)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets64,  index: 1)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets512, index: 2)
        computeEncoder.dispatchThreadgroups([ (preCullTriangleCount + 511) >> 9 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(sceneMeshReducer.markSubmeshVertexOffsets64to16PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16,  index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets16, index: 2, bound: true)
        computeEncoder.dispatchThreadgroups([ (preCullTriangleCount + 63) >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,   index: 0, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets16, index: 1, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets4,  index: 2, bound: true)
        computeEncoder.dispatchThreadgroups([ (preCullTriangleCount + 15) >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(condenseIncludedTrianglesPipelineState)
        computeEncoder.setBuffer(triangleInclusionMarkBuffer, offset: 0, index: 0)
        computeEncoder.setBuffer(bridgeBuffer,      layer: .offsets4096, index: 1, bound: true)
        
        computeEncoder.setBuffer(reducedIndexBuffer,          offset: 0, index: 3)
        computeEncoder.setBuffer(finalIndexBuffer,            offset: 0, index: 4)
        computeEncoder.setBuffer(vertexMapBuffer,   layer: .mapCounts,   index: 5)
        computeEncoder.setBuffer(vertexMapBuffer,   layer: .maps,        index: 6)
        computeEncoder.dispatchThreadgroups([ (preCullTriangleCount + 3) >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer2.waitUntilCompleted()
        
        
        
        var triangleOffset: UInt32 = 0
        
        for i in 0..<numTriangle4096Groups {
            offsets4096Pointer[i] = triangleOffset
            triangleOffset += UInt32(counts4096Pointer[i])
        }
        
        commandBuffer3.commit()
        
        sceneMeshReducer.preCullVertexCount = Int(vertexOffset)
        sceneMeshReducer.preCullTriangleCount = Int(triangleOffset)
        
        swapMeshData()
    }
    
}

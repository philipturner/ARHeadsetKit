//
//  ThirdSceneMeshMatch.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/17/21.
//

#if !os(macOS)
import Metal
import simd

extension SceneMeshMatcher {
    
    func executeThirdMatch() {
        let shouldDoThirdMatchPointer = newSmallSectorBuffer[.shouldDoThirdMatch].assumingMemoryBound(to: Bool.self)
        guard shouldDoThirdMatchPointer.pointee else {
            doingThirdMatch = false
            oldTriangleCount = preCullTriangleCount
            return
        }
        
        doingThirdMatch = true
        
        ensureBufferCapacity(type: .superNanoSector, capacity: numMicroSectors << 6)
        
        
        
        let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer.optLabel = "Third Scene Mesh Match Command Buffer"
            
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Third Scene Mesh Match - Clear Sector Marks"
        
        var fillSize = octreeAsArray.count * MemoryLayout<UInt32>.stride
        blitEncoder.fill(buffer: oldSmallSectorBuffer, layer: .mark, range: 0..<fillSize, value: 0)
        
        fillSize = numMicroSectors * MemoryLayout<UInt8>.stride
        blitEncoder.fill(buffer: oldMicroSectorBuffer, layer: .microSectorMark,     range: 0..<fillSize,      value: 0)
        blitEncoder.fill(buffer: oldMicroSectorBuffer, layer: .subMicroSectorMark,  range: 0..<fillSize,      value: 0)
        blitEncoder.fill(buffer: oldMicroSectorBuffer, layer: .superNanoSectorMark, range: 0..<fillSize << 3, value: 0)
        
        fillSize = numMicroSectors * MemoryLayout<simd_half4>.stride
        blitEncoder.fill(buffer: oldMicroSectorBuffer, layer: .microSectorColor,    range: 0..<fillSize,      value: 0)
        blitEncoder.fill(buffer: oldMicroSectorBuffer, layer: .subMicroSectorColor, range: 0..<fillSize << 3, value: 0)
        blitEncoder.fill(buffer: nanoSectorColorAlias, layer: .subsectorData,       range: 0..<fillSize << 6, value: 0)
        
        blitEncoder.endEncoding()
        
        
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Third Scene Mesh Match - Compute Pass"
        
        computeEncoder.pushOptDebugGroup("Prepare Third Mesh Match")
        
        computeEncoder.setComputePipelineState(prepareThirdMeshMatchPipelineState)
        computeEncoder.setBuffer(newReducedIndexBuffer,                      offset: 0, index: 1)
        computeEncoder.setBuffer(newReducedVertexBuffer,                     offset: 0, index: 2)
        computeEncoder.setBuffer(newToOldTriangleMatchesBuffer,              offset: 0, index: 3)
        
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .numSectorsMinus1,    index: 7)
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .mappings,            index: 8)
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .sortedHashes,        index: 9)
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .sortedHashMappings,  index: 10)
        
        computeEncoder.setBuffer(oldMicroSector512thBuffer, layer: .offsets,             index: 13)
        computeEncoder.setBuffer(oldMicroSector512thBuffer, layer: .counts,              index: 14)
        
        computeEncoder.setBuffer(oldSmallSectorBuffer,      layer: .mark,                index: 15)
        computeEncoder.setBuffer(oldMicroSectorBuffer,      layer: .microSectorMark,     index: 16)
        computeEncoder.setBuffer(oldMicroSectorBuffer,      layer: .subMicroSectorMark,  index: 17)
        computeEncoder.setBuffer(oldMicroSectorBuffer,      layer: .superNanoSectorMark, index: 18)
        computeEncoder.dispatchThreadgroups([ preCullTriangleCount ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Mark Micro Sector Colors")
        
        computeEncoder.setComputePipelineState(markMicroSectorColorsPipelineState)
        computeEncoder.setBuffer(oldReducedColorBuffer,                      offset: 0, index: 4)
        computeEncoder.setBuffer(oldReducedIndexBuffer,                      offset: 0, index: 5)
        computeEncoder.setBuffer(oldReducedVertexBuffer,                     offset: 0, index: 6)

        computeEncoder.setBuffer(oldSmallSectorBuffer, layer: .using8bitSmallSectorIDs, index: 11)
        computeEncoder.setBuffer(oldTransientSectorIDBuffer,                 offset: 0, index: 12)

        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .microSectorColor,        index: 19)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .subMicroSectorColor,     index: 20)
        computeEncoder.setBuffer(nanoSectorColorAlias, layer: .subsectorData,           index: 21)
        computeEncoder.dispatchThreads([ oldTriangleCount ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Do Third Mesh Match")
        
        computeEncoder.setComputePipelineState(executeThirdMeshMatchPipelineState)
        computeEncoder.setBuffer(newReducedColorBuffer, offset: 0, index: 0)
        computeEncoder.dispatchThreadgroups([ preCullTriangleCount ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        
        oldTriangleCount = preCullTriangleCount
    }
    
}
#endif

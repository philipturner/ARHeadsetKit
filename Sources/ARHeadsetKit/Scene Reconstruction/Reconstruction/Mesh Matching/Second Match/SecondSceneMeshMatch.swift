//
//  SecondSceneMeshMatch.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/17/21.
//

import Metal
import simd

extension SceneMeshMatcher {
    
    func executeSecondMatch() {
        let shouldDoThirdMatchPointer = newSmallSectorBuffer[.shouldDoThirdMatch].assumingMemoryBound(to: Bool.self)
        shouldDoThirdMatchPointer.pointee = false
        
        guard shouldDoMatch else {
            return
        }
        
        let using8bitSectorIDsPointer = oldSmallSectorBuffer[.using8bitSmallSectorIDs].assumingMemoryBound(to: Bool.self)
        using8bitSectorIDsPointer.pointee = sceneCuller.octreeNodeCenters.count <= 255
        
        
        
        let commandBuffer1 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer1.optLabel = "Second Scene Mesh Match Command Buffer 1"
            
        let blitEncoder = commandBuffer1.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Second Scene Mesh Match - Clear Sector Marks"
        
        var fillSize = octreeAsArray.count * MemoryLayout<UInt32>.stride
        blitEncoder.fill(buffer: oldSmallSectorBuffer, layer: .mark, range: 0..<fillSize, value: 0)
        
        fillSize = numMicroSectors * MemoryLayout<UInt8>.stride
        blitEncoder.fill(buffer: oldMicroSectorBuffer, layer: .microSectorMark, range: 0..<fillSize, value: 0)
        
        fillSize = numMicroSectors << 4 * MemoryLayout<UInt32>.stride
        blitEncoder.fill(buffer: oldMicroSectorBuffer, layer: .nanoSectorMark, range: 0..<fillSize, value: 0)
        
        let roundedNumMicroSectors = ~63 & (numMicroSectors + 63)
        fillSize = roundedNumMicroSectors * MemoryLayout<UInt16>.stride
        blitEncoder.fill(buffer: oldMicroSectorBuffer, layer: .countsIndividual, range: 0..<fillSize, value: 0)
        
        blitEncoder.endEncoding()
        
        
        
        var computeEncoder = commandBuffer1.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Second Scene Mesh Match - Compute Pass 1"
        
        computeEncoder.pushOptDebugGroup("Prepare Second Mesh Match")
        
        computeEncoder.setComputePipelineState(prepareSecondMeshMatchPipelineState)
        computeEncoder.setBuffer(newReducedIndexBuffer,                      offset: 0, index: 1)
        computeEncoder.setBuffer(newReducedVertexBuffer,                     offset: 0, index: 2)
        computeEncoder.setBuffer(newToOldTriangleMatchesBuffer,              offset: 0, index: 3)
        
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .shouldDoThirdMatch, index: 5)
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .numSectorsMinus1,   index: 6)
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .mappings,           index: 7)
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .sortedHashes,       index: 8)
        computeEncoder.setBuffer(newSmallSectorBuffer,      layer: .sortedHashMappings, index: 9)
        
        computeEncoder.setBuffer(oldMicroSector512thBuffer, layer: .offsets,            index: 12)
        computeEncoder.setBuffer(oldMicroSector512thBuffer, layer: .counts,             index: 13)
        
        computeEncoder.setBuffer(oldSmallSectorBuffer,      layer: .mark,               index: 14)
        computeEncoder.setBuffer(oldMicroSectorBuffer,      layer: .microSectorMark,    index: 15)
        computeEncoder.setBuffer(oldMicroSectorBuffer,      layer: .nanoSectorMark,     index: 16)
        computeEncoder.dispatchThreadgroups([ preCullTriangleCount ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Count Nano Sectors")
        
        computeEncoder.setComputePipelineState(countNanoSectors4thForMatchPipelineState)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .counts4th,   index: 0)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsets16th, index: 1)
        computeEncoder.dispatchThreadgroups([ numMicroSectors << 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(countNanoSectors1ForMatchPipelineState)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .countsIndividual, index: 1, bound: true)
        computeEncoder.dispatchThreadgroups([ numMicroSectors ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(countNanoSectors4to16ForMatchPipelineState)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .counts4, index: 2)
        computeEncoder.dispatchThreadgroups([ roundedNumMicroSectors >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .counts4,  index: 1, bound: true)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .counts16, index: 2, bound: true)
        computeEncoder.dispatchThreadgroups([ roundedNumMicroSectors >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(scanNanoSectors64ForMatchPipelineState)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .counts64,  index: 3)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsets16, index: 4)
        computeEncoder.dispatchThreadgroups([ roundedNumMicroSectors >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        
        computeEncoder.endEncoding()
        commandBuffer1.commit()
        
        
        
        let commandBuffer2 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer2.optLabel = "Second Scene Mesh Match Command Buffer 2"
        
        computeEncoder = commandBuffer2.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Second Scene Mesh Match - Compute Pass 2"
        
        computeEncoder.pushOptDebugGroup("Mark Nano Sector Offsets")
        
        computeEncoder.setComputePipelineState(markNanoSector16to4OffsetsForMatchPipelineState)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .counts4,   index: 2)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsets4,  index: 3)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsets16, index: 4)
        computeEncoder.dispatchThreadgroups([ roundedNumMicroSectors >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .countsIndividual,  index: 2, bound: true)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsetsIndividual, index: 3, bound: true)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsets4,          index: 4, bound: true)
        computeEncoder.dispatchThreadgroups([ roundedNumMicroSectors >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markNanoSector1OffsetsForMatchPipelineState)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .counts4th,       index: 1)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsets4th,      index: 2, bound: true)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .microSectorMark, index: 15)
        computeEncoder.dispatchThreadgroups([ numMicroSectors ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markNanoSector16thOffsetsForMatchPipelineState)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsets16th,    index: 0)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .nanoSectorMark, index: 16)
        computeEncoder.setBuffer(oldMicroSectorBuffer, layer: .offsets512th,   index: 18)
        computeEncoder.dispatchThreadgroups([ numMicroSectors << 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        
        let nanoSectorCounts64Pointer  = oldMicroSectorBuffer[.counts64].assumingMemoryBound(to: UInt16.self)
        let nanoSectorOffsets64Pointer = oldMicroSectorBuffer[.offsets64].assumingMemoryBound(to: UInt32.self)
        
        commandBuffer1.waitUntilCompleted()
        
        
        
        var nanoSectorOffset: UInt32 = 0
        
        for i in 0..<roundedNumMicroSectors >> 6 {
            nanoSectorOffsets64Pointer[i] = nanoSectorOffset
            nanoSectorOffset += UInt32(nanoSectorCounts64Pointer[i])
        }
        
        if nanoSectorOffset > 0 {
            ensureBufferCapacity(type: .nanoSector, capacity: nanoSectorOffset)
            
            computeEncoder.pushOptDebugGroup("Mark Nano Sector Colors")
            
            var threadgroupSize = roundUpToPowerOf2(.init(nanoSectorOffset) + 1) >> 1
            threadgroupSize = min(1024, threadgroupSize)
            
            computeEncoder.setComputePipelineState(clearNanoSectorColorsPipelineState)
            computeEncoder.setBuffer(nanoSectorColorAlias, layer: .subsectorData, index: 19)
            computeEncoder.dispatchThreads([ Int(nanoSectorOffset << 1) ], threadsPerThreadgroup: [ threadgroupSize ])
            
            computeEncoder.setComputePipelineState(markNanoSectorColorsPipelineState)
            computeEncoder.setBuffer(oldReducedColorBuffer,                          offset:  0, index: 0)
            computeEncoder.setBuffer(oldReducedIndexBuffer,                          offset:  0, index: 1)
            computeEncoder.setBuffer(oldReducedVertexBuffer,                         offset:  0, index: 2)
            computeEncoder.setBuffer(oldRasterizationComponentBuffer,                offset: 12, index: 4)
            
            computeEncoder.setBuffer(oldSmallSectorBuffer,      layer: .using8bitSmallSectorIDs, index: 10)
            computeEncoder.setBuffer(oldTransientSectorIDBuffer,                      offset: 0, index: 11)
            
            computeEncoder.setBuffer(oldMicroSector512thBuffer, layer: .offsets,                 index: 12)
            computeEncoder.setBuffer(oldMicroSector512thBuffer, layer: .counts,                  index: 13)
            computeEncoder.setBuffer(oldSmallSectorBuffer,      layer: .mark,                    index: 14)
            computeEncoder.setBuffer(oldMicroSectorBuffer,      layer: .offsets64,               index: 17)
            computeEncoder.dispatchThreads([ oldTriangleCount ], threadsPerThreadgroup: 1)
            
            computeEncoder.setComputePipelineState(divideNanoSectorColorsPipelineState)
            computeEncoder.dispatchThreads([ Int(nanoSectorOffset) ], threadsPerThreadgroup: 1)
            
            computeEncoder.popOptDebugGroup()
            computeEncoder.pushOptDebugGroup("Do Second Mesh Match")
            
            computeEncoder.setComputePipelineState(executeSecondMeshMatchPipelineState)
            computeEncoder.setBuffer(newReducedColorBuffer,                offset:  0, index: 0)
            computeEncoder.setBuffer(newReducedIndexBuffer,                offset:  0, index: 1)
            computeEncoder.setBuffer(newReducedVertexBuffer,               offset:  0, index: 2)
            computeEncoder.setBuffer(newToOldTriangleMatchesBuffer,        offset:  0, index: 3)
            computeEncoder.setBuffer(newRasterizationComponentBuffer,      offset: 12, index: 4)
            
            computeEncoder.setBuffer(newSmallSectorBuffer, layer: .shouldDoThirdMatch, index: 5)
            computeEncoder.setBuffer(newSmallSectorBuffer, layer: .numSectorsMinus1,   index: 6)
            computeEncoder.setBuffer(newSmallSectorBuffer, layer: .mappings,           index: 7)
            computeEncoder.setBuffer(newSmallSectorBuffer, layer: .sortedHashes,       index: 8)
            computeEncoder.setBuffer(newSmallSectorBuffer, layer: .sortedHashMappings, index: 9)
            computeEncoder.dispatchThreadgroups([ preCullTriangleCount ], threadsPerThreadgroup: 1)
            
            computeEncoder.popOptDebugGroup()
            
            computeEncoder.endEncoding()
            commandBuffer2.commit()
        } else {
            computeEncoder.endEncoding()
        }
        
        checkOldBufferSizes()
    }
    
}

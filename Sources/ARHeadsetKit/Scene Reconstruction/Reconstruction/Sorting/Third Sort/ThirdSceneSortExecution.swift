//
//  ThirdSceneSortExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import simd

extension ThirdSceneSorter {
    
    func executeThirdSort() {
        secondSceneSorter.previousCommandBuffer2 = nil
        secondSceneSorter.swapVertexBuffers()
        
        let numSmallSectors = octreeAsArray.count
        ensureBufferCapacity(type: .smallSector, capacity: numSmallSectors)
        
        let smallSector256GroupOffsetPointer = bridgeBuffer[.smallSector256GroupOffset].assumingMemoryBound(to: UInt16.self)
        let smallSectorCountPointer          = bridgeBuffer[.smallSectorCount].assumingMemoryBound(to: UInt16.self)
        let smallSectorOffsetPointer         = bridgeBuffer[.smallSectorOffset].assumingMemoryBound(to: UInt32.self)
        let smallSectorBoundsPointer         = bridgeBuffer[.smallSectorBounds].assumingMemoryBound(to: simd_float2x3.self)
        
        var num256Groups = 0
        
        for i in 0..<numSmallSectors {
            let meshMatchingTolerance: Float = 2.4 / 256.0
            
            let node = octreeAsArray[i].node
            let position = node.center
            smallSectorBoundsPointer[i] = simd_float2x3(position, position)
                                        + simd_float2x3(simd_float3(repeating: -1 - meshMatchingTolerance),
                                                        simd_float3(repeating: -1 + meshMatchingTolerance))
            smallSectorCountPointer[i]  = UInt16(node.count)
            smallSectorOffsetPointer[i] = node.offset
            
            smallSector256GroupOffsetPointer[i] = UInt16(num256Groups)
            num256Groups += Int(node.count + 255) >> 8
        }
        
        smallSector256GroupOffsetPointer[numSmallSectors] = UInt16(num256Groups)
        
        let numVertex16Groups = num256Groups << 4
        ensureBufferCapacity(type: .initialVertex, capacity: numVertex16Groups << 4)
        
        
        
        let commandBuffer1 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer1.optLabel = "Third Scene Sort Command Buffer 1"
        
        let blitEncoder = commandBuffer1.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Third Scene Sort - Clear Atomic Count Buffer"
        
        let numAtomicCounts = (~1 & (numSmallSectors + 1)) << 9
        let fillSize = numAtomicCounts * MemoryLayout<UInt32>.stride
        blitEncoder.fill(buffer: microSector512thBuffer, layer: .counts, range: 0..<fillSize, value: 0)
        blitEncoder.endEncoding()
        
        
        
        var computeEncoder = commandBuffer1.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Third Scene Sort - Compute Pass 1"
        
        computeEncoder.pushOptDebugGroup("Mark Micro Sectors")
        
        computeEncoder.setComputePipelineState(prepareMarkMicroSectorsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer,     layer: .smallSector256GroupOffset, index: 0)
        computeEncoder.setBuffer(vertexDataBuffer, layer: .smallSectorID,             index: 1)
        computeEncoder.dispatchThreadgroups([ numSmallSectors ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer,           layer: .smallSectorCount,  index: 2)
        computeEncoder.setBuffer(bridgeBuffer,           layer: .smallSectorOffset, index: 3)
        computeEncoder.setBuffer(bridgeBuffer,           layer: .smallSectorBounds, index: 4)
        
        computeEncoder.setBuffer(sourceVertexBuffer,                     offset: 0, index: 5)
        computeEncoder.setBuffer(reducedVertexBuffer,                    offset: 0, index: 6)
        computeEncoder.setBuffer(microSector512thBuffer, layer: .counts,            index: 7)
        computeEncoder.setBuffer(vertexDataBuffer,       layer: .subsectorData,     index: 8)
        
        computeEncoder.setComputePipelineState(markMicroSectorsPipelineState)
        computeEncoder.dispatchThreadgroups([ numVertex16Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Pool Small Sector Counts")
        
        computeEncoder.setComputePipelineState(poolSmallSector128thCountsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts128th,                   index: 9)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectors128th,          index: 10)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCounts128th, index: 11)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(poolSmallSector32ndTo8thCountsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts32nd,                   index: 12)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectors32nd,          index: 13)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCounts32nd, index: 14)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts32nd,                   index: 9,  bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectors32nd,          index: 10, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCounts32nd, index: 11, bound: true)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts8th,                    index: 12, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectors8th,           index: 13, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCounts8th,  index: 14, bound: true)
        computeEncoder.dispatchThreads([ numAtomicCounts >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(poolSmallSectorHalfCountsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .countsHalf,                   index: 9,  bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectorsHalf,          index: 10, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCountsHalf, index: 11, bound: true)
        computeEncoder.dispatchThreads([ numAtomicCounts >> 8 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(scanSmallSectors2PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsetsHalf,                   index: 12, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSectorOffsetsHalf,        index: 13, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupOffsetsHalf, index: 14, bound: true)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts2,                       index: 15)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectors2,              index: 16)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCounts2,     index: 17)
        computeEncoder.dispatchThreads([ numAtomicCounts >> 10 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer1.commit()
        
        
        
        let commandBuffer2 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer2.optLabel = "Third Scene Sort Command Buffer 2"
        
        computeEncoder = commandBuffer2.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Third Scene Sort - Compute Pass 2"
        
        computeEncoder.pushOptDebugGroup("Mark Small Sector Offsets")
        
        computeEncoder.setComputePipelineState(markSmallSectorHalfTo32ndOffsetsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts8th,                     index: 13)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectors8th,            index: 14)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCounts8th,   index: 15)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets8th,                    index: 16)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSectorOffsets8th,         index: 17)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupOffsets8th,  index: 18)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsetsHalf,                   index: 19)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSectorOffsetsHalf,        index: 20)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupOffsetsHalf, index: 21)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 8 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts32nd,                    index: 13, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectors32nd,           index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCounts32nd,  index: 15, bound: true)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets32nd,                   index: 16, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSectorOffsets32nd,        index: 17, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupOffsets32nd, index: 18, bound: true)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets8th,                    index: 19, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSectorOffsets8th,         index: 20, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupOffsets8th,  index: 21, bound: true)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts128th,                    index: 13, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numMicroSectors128th,           index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupCounts128th,  index: 15, bound: true)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets128th,                   index: 16, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSectorOffsets128th,        index: 17, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupOffsets128th, index: 18, bound: true)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets32nd,                    index: 19, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSectorOffsets32nd,         index: 20, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .microSector32GroupOffsets32nd,  index: 21, bound: true)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer,     layer: .smallSector256GroupOffset, index: 0)
        computeEncoder.setBuffer(vertexDataBuffer, layer: .smallSectorID,             index: 1)
        computeEncoder.setBuffer(bridgeBuffer,     layer: .smallSectorCount,          index: 2)
        computeEncoder.setBuffer(bridgeBuffer,     layer: .smallSectorOffset,         index: 3)
        computeEncoder.setBuffer(bridgeBuffer,     layer: .offsets2,                  index: 4)
        
        computeEncoder.setBuffer(sourceVertexBuffer,                 offset: 0, index: 5)
        computeEncoder.setBuffer(microSector512thBuffer, layer: .offsets,       index: 8)
        computeEncoder.setBuffer(vertexDataBuffer,       layer: .subsectorData, index: 9)
        
        computeEncoder.setComputePipelineState(markSmallSector128thOffsetsPipelineState)
        computeEncoder.setBuffer(microSector512thBuffer, layer: .counts,                     index: 10)
        computeEncoder.setBuffer(bridgeBuffer,           layer: .microSectorOffsets2,        index: 23)
        computeEncoder.setBuffer(bridgeBuffer,           layer: .microSector32GroupOffsets2, index: 24)
        
        let counts2Pointer                    = bridgeBuffer[.counts2].assumingMemoryBound(to: UInt16.self)
        let numMicroSectors2Pointer           = bridgeBuffer[.numMicroSectors2].assumingMemoryBound(to: UInt16.self)
        let microSector32GroupCounts2Pointer  = bridgeBuffer[.microSector32GroupCounts2].assumingMemoryBound(to: UInt16.self)
        
        let offsets2Pointer                   = bridgeBuffer[.offsets2].assumingMemoryBound(to: UInt32.self)
        let microSectorOffsets2Pointer        = bridgeBuffer[.microSectorOffsets2].assumingMemoryBound(to: UInt16.self)
        let microSector32GroupOffsets2Pointer = bridgeBuffer[.microSector32GroupOffsets2].assumingMemoryBound(to: UInt16.self)
        
        commandBuffer1.waitUntilCompleted()
        
        
        
        var offset: UInt32 = 0
        var microSectorOffset: UInt16 = 0
        var microSector32GroupOffset: UInt16 = 0
        
        for i in 0..<numAtomicCounts >> 10 {
            offsets2Pointer[i]                   = offset
            microSectorOffsets2Pointer[i]        = microSectorOffset
            microSector32GroupOffsets2Pointer[i] = microSector32GroupOffset
            
            offset                   += UInt32(counts2Pointer[i])
            microSectorOffset        += numMicroSectors2Pointer[i]
            microSector32GroupOffset += microSector32GroupCounts2Pointer[i]
        }
        
        ensureBufferCapacity(type: .finalVertex, capacity: offset)
        ensureBufferCapacity(type: .microSector, capacity: microSectorOffset)
        
        computeEncoder.setBuffer(microSectorBuffer, layer: .offsetsFinal,                     index: 7)
        computeEncoder.setBuffer(microSectorBuffer, layer: .countsFinal,                      index: 19)
        computeEncoder.setBuffer(microSectorBuffer, layer: .microSector32GroupOffsetsFinal,   index: 20)
        computeEncoder.setBuffer(microSectorBuffer, layer: .microSectorToSmallSectorMappings, index: 21)
        computeEncoder.setBuffer(microSectorBuffer, layer: .microSectorIDsInSmallSectors,     index: 22)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Fill Micro Sectors")
        
        computeEncoder.setComputePipelineState(fillMicroSectorsPipelineState)
        computeEncoder.setBuffer(destinationVertexBuffer, offset: 0, index: 6)
        computeEncoder.dispatchThreadgroups([ numVertex16Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer2.commit()
        
        fourthSceneSorter.numMicroSectors = Int(microSectorOffset)
        fourthSceneSorter.numVertex32Groups = Int(microSector32GroupOffset)
    }
    
}
#endif

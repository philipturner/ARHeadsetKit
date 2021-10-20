//
//  FourthSceneSortExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import simd

extension FourthSceneSorter {
    
    func executeFourthSort() {
        let numVertex16Groups = numVertex32Groups << 1
        ensureBufferCapacity(type: .microSector,   capacity: numMicroSectors)
        ensureBufferCapacity(type: .initialVertex, capacity: numVertex16Groups << 4)
        
        let commandBuffer1 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer1.optLabel = "Fourth Scene Sort Command Buffer 1"
        
        let blitEncoder = commandBuffer1.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Fourth Scene Sort - Clear Atomic Count Buffer"
        
        let fillSize = numMicroSectors << 9 * MemoryLayout<UInt8>.stride
        blitEncoder.fill(buffer: nanoSector512thBuffer, layer: .counts512th, range: 0..<fillSize, value: 0)
        
        let num64Groups = (numMicroSectors + 63) >> 6
        let numAtomicCounts = num64Groups << 15
        
        let num4thThreads = numMicroSectors << 2
        let fillStart = num4thThreads * MemoryLayout<UInt8>.stride
        let fillEnd = numAtomicCounts >> 7 * MemoryLayout<UInt8>.stride
        if fillStart < fillEnd {
            blitEncoder.fill(buffer: bridgeBuffer, layer: .numNanoSectors4th, range: fillStart..<fillEnd, value: 0)
        }
        
        blitEncoder.endEncoding()
        
        
        
        var computeEncoder = commandBuffer1.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Fourth Scene Sort - Compute Pass 1"
        
        computeEncoder.pushOptDebugGroup("Mark Nano Sectors")
        
        computeEncoder.setComputePipelineState(prepareMarkNanoSectorsPipelineState)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .microSector32GroupOffsetsFinal, index: 2)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .countsFinal,                    index: 3)
        computeEncoder.setBuffer(vertexDataBuffer,        layer: .microSectorID,                  index: 7)
        computeEncoder.dispatchThreadgroups([ numMicroSectors ], threadsPerThreadgroup: 1)
            
        computeEncoder.setComputePipelineState(markNanoSectorsPipelineState)
        computeEncoder.setBuffer(sourceBridgeBuffer,      layer: .offsets2,                         index: 0)
        computeEncoder.setBuffer(sourceBridgeBuffer,      layer: .smallSectorBounds,                index: 1)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .offsetsFinal,                     index: 4)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .microSectorToSmallSectorMappings, index: 5)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .microSectorIDsInSmallSectors,     index: 6)
        
        computeEncoder.setBuffer(sourceVertexBuffer,                                     offset: 0, index: 8)
        computeEncoder.setBuffer(reducedVertexBuffer,                                    offset: 0, index: 9)
        computeEncoder.setBuffer(nanoSector512thBuffer,   layer: .counts512th,                      index: 10)
        computeEncoder.setBuffer(vertexDataBuffer,        layer: .subsectorData,                    index: 11)
        computeEncoder.dispatchThreadgroups([ numVertex16Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Pool Micro Sector Counts")
        
        computeEncoder.setComputePipelineState(poolMicroSector4thCountsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4th,         index: 12)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectors4th, index: 13)
        computeEncoder.setBuffer(bridgeBuffer, layer: .inclusions32nd,    index: 19)
        computeEncoder.dispatchThreadgroups([ num4thThreads ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(poolMicroSectorIndividualCountsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .countsIndividual,         index: 14)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectorsIndividual, index: 15)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 9 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(poolMicroSector4to16CountsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,         index: 12, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectors4, index: 13, bound: true)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 11 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,          index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectors4,  index: 15, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts16,         index: 12, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectors16, index: 13, bound: true)
        computeEncoder.dispatchThreadgroups([ numAtomicCounts >> 13 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(scanMicroSectors64PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts64,            index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectors64,    index: 15, bound: true)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets16,           index: 16)
        computeEncoder.setBuffer(bridgeBuffer, layer: .nanoSectorOffsets16, index: 17)
        computeEncoder.dispatchThreadgroups([ num64Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer1.commit()
        
        
        
        let commandBuffer2 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer2.optLabel = "Fourth Scene Sort Command Buffer 2"
            
        computeEncoder = commandBuffer2.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Fourth Scene Sort - Compute Pass 2"
        
        computeEncoder.pushOptDebugGroup("Mark Micro Sector Offsets")
        
        computeEncoder.setComputePipelineState(markMicroSector16to4OffsetsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4,             index: 13)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectors4,     index: 14)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets16,           index: 15)
        computeEncoder.setBuffer(bridgeBuffer, layer: .nanoSectorOffsets16, index: 16)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets4,            index: 17)
        computeEncoder.setBuffer(bridgeBuffer, layer: .nanoSectorOffsets4,  index: 18)
        computeEncoder.dispatchThreadgroups([ (numMicroSectors + 15) >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .countsIndividual,            index: 13, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectorsIndividual,    index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets4,                    index: 15, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .nanoSectorOffsets4,          index: 16, bound: true)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsetsIndividual,           index: 17, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .nanoSectorOffsetsIndividual, index: 18, bound: true)
        computeEncoder.dispatchThreadgroups([ (numMicroSectors + 3) >> 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markMicroSectorIndividualOffsetsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts4th,            index: 13, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numNanoSectors4th,    index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets4th,           index: 15, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .nanoSectorOffsets4th, index: 16, bound: true)
        computeEncoder.dispatchThreadgroups([ numMicroSectors ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(sourceBridgeBuffer,      layer: .offsets2,                         index: 0)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .microSector32GroupOffsetsFinal,   index: 1)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .countsFinal,                      index: 2)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .offsetsFinal,                     index: 3)
        computeEncoder.setBuffer(sourceMicroSectorBuffer, layer: .microSectorToSmallSectorMappings, index: 4)
        computeEncoder.setBuffer(vertexDataBuffer,        layer: .microSectorID,                    index: 5)
        computeEncoder.setBuffer(nanoSector512thBuffer,   layer: .offsets64,                        index: 6)
        
        computeEncoder.setBuffer(sourceVertexBuffer,                                     offset: 0, index: 7)
        computeEncoder.setBuffer(vertexDataBuffer,        layer: .subsectorData,                    index: 10)
        
        computeEncoder.setComputePipelineState(markMicroSector4thOffsetsPipelineState)
        computeEncoder.setBuffer(nanoSector512thBuffer, layer: .offsets512th,        index: 9)
        computeEncoder.setBuffer(nanoSector512thBuffer, layer: .counts512th,         index: 11)
        computeEncoder.setBuffer(bridgeBuffer,          layer: .nanoSectorOffsets64, index: 17, bound: true)
        computeEncoder.setBuffer(bridgeBuffer,          layer: .inclusions32nd,      index: 19)
        
        let counts64Pointer            = bridgeBuffer[.counts64].assumingMemoryBound(to: UInt16.self)
        let numNanoSectors64Pointer    = bridgeBuffer[.numNanoSectors64].assumingMemoryBound(to: UInt16.self)
        
        let offsets64Pointer           = nanoSector512thBuffer[.offsets64].assumingMemoryBound(to: UInt32.self)
        let nanoSectorOffsets64Pointer = bridgeBuffer[.nanoSectorOffsets64].assumingMemoryBound(to: UInt32.self)
        
        commandBuffer1.waitUntilCompleted()
        
        
        
        var offset: UInt32 = 0
        var nanoSectorOffset: UInt32 = 0
        
        for i in 0..<num64Groups {
            offsets64Pointer[i]           = offset
            nanoSectorOffsets64Pointer[i] = nanoSectorOffset
            
            offset += UInt32(counts64Pointer[i])
            nanoSectorOffset += UInt32(numNanoSectors64Pointer[i])
        }
        
        ensureBufferCapacity(type: .finalVertex, capacity: offset)
        ensureBufferCapacity(type: .nanoSector,  capacity: nanoSectorOffset)
        
        computeEncoder.setBuffer(mappingsFinalBuffer, offset: 0, index: 13)
        computeEncoder.dispatchThreadgroups([ num4thThreads ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Fill Nano Sectors")
        
        computeEncoder.setComputePipelineState(fillNanoSectorsPipelineState)
        computeEncoder.setBuffer(destinationVertexBuffer, offset: 0, index: 8)
        computeEncoder.dispatchThreadgroups([ numVertex16Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer2.commit()
        
        numNanoSectors = Int(nanoSectorOffset)
        finalVertexCount = Int(offset)
    }
    
}
#endif

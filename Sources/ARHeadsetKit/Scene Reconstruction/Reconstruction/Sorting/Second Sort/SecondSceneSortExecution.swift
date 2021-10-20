//
//  SecondSceneSortExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import simd

extension SecondSceneSorter {
    
    func swapVertexBuffers() {
        swap(&sourceVertexBuffer, &destinationVertexBuffer)
        
        sourceVertexBuffer.optLabel = "Second Scene Sorter Source Vertex Buffer"
        destinationVertexBuffer.optLabel = "Second/Third Scene Sorter Destination Vertex Buffer"
    }
    
    func executeSecondSort() {
        swapVertexBuffers()
        
        let focusNodes = octreeAsArray.filter{ $0.node.size == smallSectorSize }
        let numFocusNodes = focusNodes.count
        
        ensureBufferCapacity(type: .largeSector, capacity: numFocusNodes)
        
        let largeSectorBoundsPointer = largeSectorBuffer[.bounds].assumingMemoryBound(to: simd_float2x3.self)
        let numVertexThreadsPointer  = largeSectorBuffer[.numVertexThreads].assumingMemoryBound(to: UInt32.self)
        
        var counts             = [Int](capacity: numFocusNodes)
        var expandedCounts     = [Int](capacity: numFocusNodes)
        var bufferSubdivisions = [Int](unsafeUninitializedCapacity: numFocusNodes + 1) { pointer, count in
            pointer[0] = 0
            count = 1
        }
        
        for i in 0..<numFocusNodes {
            let meshMatchingTolerance: Float = 2.4 / 256.0
            
            let boundsVector = focusNodes[i].node.center
            largeSectorBoundsPointer[i] = simd_float2x3(boundsVector, boundsVector)
                                        + simd_float2x3(simd_float3(repeating: -meshMatchingTolerance),
                                                        simd_float3(repeating:  meshMatchingTolerance))
            let count = focusNodes[i].node.count
            numVertexThreadsPointer[i] = count
            counts.append(Int(count))
            
            let expandedCount = ~2047 & Int(count + 2047)
            expandedCounts.append(expandedCount)
            bufferSubdivisions.append(bufferSubdivisions[i] + expandedCount)
        }
        
        let expandedVertexCount = bufferSubdivisions[numFocusNodes]
        ensureBufferCapacity(type: .bridge, capacity: expandedVertexCount)
        
        
        
        let commandBuffer1 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer1.optLabel = "Second Scene Sort Command Buffer 1"
        
        var computeEncoder = commandBuffer1.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Second Scene Sort - Compute Pass 1"
        
        computeEncoder.pushOptDebugGroup("Mark Large Sector Octants")
        
        computeEncoder.setComputePipelineState(markLargeSectorOctantsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer,      layer: .octantMark,       index: 0)
        computeEncoder.setBuffer(largeSectorBuffer, layer: .numVertexThreads, index: 1)
        computeEncoder.setBuffer(largeSectorBuffer, layer: .bounds,           index: 2)
        computeEncoder.setBuffer(reducedVertexBuffer,              offset: 0, index: 4)
        
        let sourceVertexStride = MemoryLayout<UInt32>.stride
        computeEncoder.setBuffer(sourceVertexBuffer, offset: Int(focusNodes[0].node.offset) * sourceVertexStride, index: 3)
        computeEncoder.dispatchThreadgroups([ expandedCounts[0] ], threadsPerThreadgroup: 1)
        
        let octantMarkStride       = MemoryLayout<UInt8>.stride
        let numVertexThreadsStride = MemoryLayout<UInt32>.stride
        let boundsStride           = MemoryLayout<simd_float2x3>.stride
        
        var numVertexThreadsOffset = numVertexThreadsStride
        var boundsOffset           = boundsStride
        
        for i in 1..<numFocusNodes {
            let octantMarkOffset   = bufferSubdivisions[i] * octantMarkStride
            let sourceVertexOffset = Int(focusNodes[i].node.offset) * sourceVertexStride
            
            computeEncoder.setBuffer(bridgeBuffer,      layer: .octantMark,       offset: octantMarkOffset,       index: 0, bound: true)
            computeEncoder.setBuffer(largeSectorBuffer, layer: .numVertexThreads, offset: numVertexThreadsOffset, index: 1, bound: true)
            computeEncoder.setBuffer(largeSectorBuffer, layer: .bounds,           offset: boundsOffset,           index: 2, bound: true)
            computeEncoder.setBufferOffset(                                               sourceVertexOffset,     index: 3)
            
            computeEncoder.dispatchThreads([ expandedCounts[i] ], threadsPerThreadgroup: 1)
            
            numVertexThreadsOffset += numVertexThreadsStride
            boundsOffset           += boundsStride
        }
        
        if numFocusNodes > 1 {
            computeEncoder.setBuffer(bridgeBuffer, layer: .octantMark, offset: 0, index: 0, bound: true)
        }
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Pool Large Sector Octants")
        
        computeEncoder.setComputePipelineState(poolLargeSectorOctantCounts16PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantCounts16, index: 5)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(poolLargeSectorOctantCounts128PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantCounts128, index: 6)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 7 ], threadsPerThreadgroup: 1)
        
        let totalNum2048Groups = expandedVertexCount >> 11
        computeEncoder.setComputePipelineState(poolLargeSectorOctantCounts2048PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantCounts2048, index: 7)
        computeEncoder.dispatchThreadgroups([ totalNum2048Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer1.commit()
        previousCommandBuffer2?.waitUntilCompleted()
        
        let idBufferOffsets2048_inPointer = bridgeBuffer[.idBufferOffsets2048].assumingMemoryBound(to: UInt32.self)
        var vertex2048GroupIndex = 0
        
        for i in 0..<numFocusNodes {
            var offset = focusNodes[i].node.offset
            
            for _ in 0..<expandedCounts[i] >> 11 {
                idBufferOffsets2048_inPointer[vertex2048GroupIndex] = offset
                vertex2048GroupIndex += 1
                offset += 2048
            }
        }
        
        
        
        let commandBuffer2 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer2.optLabel = "Second Scene Sort Command Buffer 2"
        
        computeEncoder = commandBuffer2.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Second Scene Sort - Compute Pass 2"
        
        computeEncoder.pushOptDebugGroup("Mark Large Sector Octant Offsets")
        
        computeEncoder.setComputePipelineState(markLargeSectorOctantOffsets2048PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantCounts128,   index: 6)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantOffsets2048, index: 8)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantOffsets128,  index: 9)
        computeEncoder.dispatchThreadgroups([ totalNum2048Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markLargeSectorOctantOffsets128PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantCounts16,  index: 5)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantOffsets16, index: 10)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 7 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Fill Large Sector Octants")
        
        computeEncoder.setComputePipelineState(fillLargeSectorOctantsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantMark,          index: 0)
        computeEncoder.setBuffer(sourceVertexBuffer,             offset: 0, index: 3)
        computeEncoder.setBuffer(bridgeBuffer, layer: .idBufferOffsets2048, index: 11)
        
        var countsArray_focus_expanded = [UInt32](capacity: numFocusNodes << 3)
        
        var counts2048Pointer  = bridgeBuffer[.octantCounts2048].assumingMemoryBound(to: OctantCounts_16bit.self)
        var offsets2048Pointer = bridgeBuffer[.octantOffsets2048].assumingMemoryBound(to: OctantOffsets_32bit.self)
        
        commandBuffer1.waitUntilCompleted()
        
        
        
        for i in 0..<numFocusNodes {
            let num2048Groups = expandedCounts[i] >> 11
            
            var lowerCounts = simd_uint4()
            var upperCounts = simd_uint4()
            
            for j in 0..<num2048Groups {
                let counts = counts2048Pointer[j]
                
                if any(counts.lowerCounts .> 0) {
                    offsets2048Pointer[j].lowerMarks = lowerCounts
                    lowerCounts &+= simd_uint4(truncatingIfNeeded: counts.lowerCounts)
                }
                
                if any(counts.upperCounts .> 0) {
                    offsets2048Pointer[j].upperMarks = upperCounts
                    upperCounts &+= simd_uint4(truncatingIfNeeded: counts.upperCounts)
                }
            }
            
            countsArray_focus_expanded += [lowerCounts.x, lowerCounts.y, lowerCounts.z, lowerCounts.w,
                                           upperCounts.x, upperCounts.y, upperCounts.z, upperCounts.w]
            
            counts2048Pointer  += num2048Groups
            offsets2048Pointer += num2048Groups
        }
        
        let numOctreeElements = octreeAsArray.count
        var countsArray_compressed      = [UInt32](capacity: numOctreeElements)
        var offsetsArray_compressed     = [UInt32](capacity: numOctreeElements)
        var offsetsArray_focus_expanded = [UInt32](capacity: numOctreeElements << 3)
        
        var isFocusArray        = [Bool]  (capacity: numOctreeElements)
        var originalOffsetArray = [UInt32](capacity: numOctreeElements)
        
        var currentOffset: UInt32 = 0
        var currentFocusNode = focusNodes[0]
        var arrayIterator_focus = 0
        
        for arrayElement in octreeAsArray {
            offsetsArray_compressed.append(currentOffset)
            originalOffsetArray.append(arrayElement.node.offset)
            
            if arrayElement.path.elementsEqual(currentFocusNode.path) {
                isFocusArray.append(true)
                
                let previousOffset = currentOffset
                var arrayIterator_focus_expanded = arrayIterator_focus << 3
                
                for _ in 0..<8 {
                    offsetsArray_focus_expanded.append(currentOffset)
                    
                    let selectedCount = countsArray_focus_expanded[arrayIterator_focus_expanded]
                    
                    currentOffset += selectedCount
                    arrayIterator_focus_expanded += 1
                }
                
                countsArray_compressed.append(currentOffset - previousOffset)
                arrayIterator_focus += 1
                
                if arrayIterator_focus < focusNodes.count {
                    currentFocusNode = focusNodes[arrayIterator_focus]
                }
            } else {
                isFocusArray.append(false)
                
                let selectedCount = arrayElement.node.count
                countsArray_compressed.append(selectedCount)
                
                currentOffset += selectedCount
            }
        }
        
        ensureBufferCapacity(type: .vertex, capacity: currentOffset)
        
        counts2048Pointer  -= totalNum2048Groups
        offsets2048Pointer -= totalNum2048Groups
        
        arrayIterator_focus = 0
        
        for i in 0..<octreeAsArray.count {
            sceneSorter.octreeAsArray[i].node.count  = countsArray_compressed[i]
            sceneSorter.octreeAsArray[i].node.offset = offsetsArray_compressed[i]
            
            if isFocusArray[i] {
                let num2048Groups = expandedCounts[arrayIterator_focus] >> 11
                var arrayIterator_focus_expanded = arrayIterator_focus << 3
                
                let lowerAdditionalOffsets = simd_uint4(offsetsArray_focus_expanded[arrayIterator_focus_expanded    ],
                                                        offsetsArray_focus_expanded[arrayIterator_focus_expanded + 1],
                                                        offsetsArray_focus_expanded[arrayIterator_focus_expanded + 2],
                                                        offsetsArray_focus_expanded[arrayIterator_focus_expanded + 3])
                
                let upperAdditionalOffsets = simd_uint4(offsetsArray_focus_expanded[arrayIterator_focus_expanded + 4],
                                                        offsetsArray_focus_expanded[arrayIterator_focus_expanded + 5],
                                                        offsetsArray_focus_expanded[arrayIterator_focus_expanded + 6],
                                                        offsetsArray_focus_expanded[arrayIterator_focus_expanded + 7])
                
                for j in 0..<num2048Groups {
                    let counts = counts2048Pointer[j]
                    
                    if any(counts.lowerCounts .> 0) {
                        offsets2048Pointer[j].lowerMarks &+= lowerAdditionalOffsets
                    }
                    
                    if any(counts.upperCounts .> 0) {
                        offsets2048Pointer[j].upperMarks &+= upperAdditionalOffsets
                    }
                }
                
                counts2048Pointer  += num2048Groups
                offsets2048Pointer += num2048Groups
                
                sceneSorter.octreeAsArray[i].node.nextNodes = Array(repeating: nil, count: 8)
                
                let size_half    = octreeAsArray[i].node.size * 0.5
                let parentCenter = octreeAsArray[i].node.center
                
                for octantID in 0..<8 {
                    let count = countsArray_focus_expanded[arrayIterator_focus_expanded]
                    guard count > 0 else {
                        arrayIterator_focus_expanded += 1
                        continue
                    }
                    
                    let offset = offsetsArray_focus_expanded[arrayIterator_focus_expanded]
                    let spaceOffset = OctreeNode.normalizedOffset(for: octantID) * size_half + parentCenter
                    sceneSorter.octreeAsArray[i].node.nextNodes[octantID] = OctreeNode(count, offset, simd_float4(spaceOffset, size_half))
                    
                    arrayIterator_focus_expanded += 1
                }
                
                arrayIterator_focus += 1
            }
        }
        
        computeEncoder.setBuffer(destinationVertexBuffer, offset: 0, index: 12)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        if numFocusNodes < octreeAsArray.count {
            let blitEncoder = commandBuffer2.makeBlitCommandEncoder()!
            blitEncoder.optLabel = "Second Scene Sort - Copy Non-Modified Sectors"
            
            for i in 0..<octreeAsArray.count {
                guard !isFocusArray[i] else {
                    continue
                }
                
                let numBytes         = Int(octreeAsArray[i].node.count) * MemoryLayout<UInt32>.stride
                let sourceStart      = Int(originalOffsetArray[i])      * MemoryLayout<UInt32>.stride
                let destinationStart = Int(offsetsArray_compressed[i])  * MemoryLayout<UInt32>.stride
                
                blitEncoder.copy(from: sourceVertexBuffer,      sourceOffset:       sourceStart,
                                 to:   destinationVertexBuffer, destinationOffset:  destinationStart, size: numBytes)
            }
            
            blitEncoder.endEncoding()
        }
        
        commandBuffer2.commit()
        previousCommandBuffer2 = commandBuffer2
        
        sceneSorter.firstNode = OctreeNode.reconstructOctree(octreeAsArray, octantSize: worldOctantSize)
        sceneSorter.octreeAsArray = firstNode.array
        
        smallSectorSize *= 0.5
    }
    
}
#endif

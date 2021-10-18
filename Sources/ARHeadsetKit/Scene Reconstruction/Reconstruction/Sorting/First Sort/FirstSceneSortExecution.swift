//
//  FirstSceneSortExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

extension FirstSceneSorter {
    
    func executeFirstSort() {
        let expandedVertexCount = ~4095 & (preCullVertexCount + 4095)
        ensureBufferCapacity(type: .vertex, capacity: expandedVertexCount)
        
        let numVertexThreadsPointer = bridgeBuffer[.numVertexThreads].assumingMemoryBound(to: UInt32.self)
        numVertexThreadsPointer.pointee = UInt32(preCullVertexCount)
        
        
        
        let commandBuffer1 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer1.optLabel = "First Scene Sort Command Buffer 1"
            
        var computeEncoder = commandBuffer1.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "First Scene Sort - Compute Pass 1"
        
        computeEncoder.pushOptDebugGroup("Mark World Octants")
        
        computeEncoder.setComputePipelineState(markWorldOctantsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantMark,       index: 0)
        computeEncoder.setBuffer(reducedVertexBuffer,         offset: 0, index: 1)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numVertexThreads, index: 2)
        computeEncoder.dispatchThreadgroups([ preCullVertexCount ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Pool World Octant Data")
        
        computeEncoder.setComputePipelineState(poolWorldOctantData16PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantData16, index: 3)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(poolWorldOctantData256PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantData256, index: 4)
        computeEncoder.dispatchThreadgroups([ expandedVertexCount >> 8 ], threadsPerThreadgroup: 1)
        
        let num4096Groups = expandedVertexCount >> 12
        computeEncoder.setComputePipelineState(poolWorldOctantData4096PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantData4096, index: 5)
        computeEncoder.dispatchThreadgroups([ num4096Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer1.commit()
        
        
        
        let commandBuffer2 = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer2.optLabel = "First Scene Sort Command Buffer 2"
        
        computeEncoder = commandBuffer2.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "First Scene Sort - Compute Pass 2"
        
        computeEncoder.pushOptDebugGroup("Mark World Octant Offsets")
        
        computeEncoder.setComputePipelineState(markWorldOctantOffsets4096PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .numVertexThreads,  index: 2)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantData256,     index: 4)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantOffsets4096, index: 6)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantOffsets256,  index: 7)
        computeEncoder.dispatchThreadgroups([ num4096Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markWorldOctantOffsets256PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantData16,    index: 3)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantOffsets16, index: 8)
        computeEncoder.dispatchThreadgroups([ (preCullVertexCount + 255) >> 8 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Fill World Octants")
        
        computeEncoder.setComputePipelineState(fillWorldOctantsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .octantMark, index: 0)
        
        let octantData4096Pointer    = bridgeBuffer[.octantData4096].assumingMemoryBound(to: OctantData_16bit.self)
        let octantOffsets4096Pointer = bridgeBuffer[.octantOffsets4096].assumingMemoryBound(to: OctantOffsets_32bit.self)
        
        commandBuffer1.waitUntilCompleted()
        
        
        
        var lowerCounts = simd_uint4()
        var upperCounts = simd_uint4()
        var lowerSizes = simd_uchar4()
        var upperSizes = simd_uchar4()
        
        for i in 0..<num4096Groups {
            let octantData = octantData4096Pointer[i]
            
            if any(octantData.sizes.lower .> 0) {
                octantOffsets4096Pointer[i].lowerMarks = lowerCounts
                lowerCounts &+= simd_uint4(truncatingIfNeeded: octantData.lowerCounts)
                lowerSizes = simd_max(lowerSizes, octantData.sizes.lower)
            }
            
            if any(octantData.sizes.upper .> 0) {
                octantOffsets4096Pointer[i].upperMarks = upperCounts
                upperCounts &+= simd_uint4(truncatingIfNeeded: octantData.upperCounts)
                upperSizes = simd_max(upperSizes, octantData.sizes.upper)
            }
        }
        
        var lowerOffsets = simd_make_uint4_undef(simd_uint2(0, lowerCounts[0]))
        lowerOffsets.z = lowerOffsets.y + lowerCounts[1]
        lowerOffsets.w = lowerOffsets.z + lowerCounts[2]
        
        var upperOffsets = simd_make_uint4_undef(lowerOffsets.w + lowerCounts[3])
        upperOffsets.y = upperOffsets.x + upperCounts[0]
        upperOffsets.z = upperOffsets.y + upperCounts[1]
        upperOffsets.w = upperOffsets.z + upperCounts[2]
        
        let newVertexCapacity = upperOffsets.w + upperCounts[3]
        secondSceneSorter.ensureBufferCapacity(type: .vertex, capacity: newVertexCapacity)
        
        for i in 0..<num4096Groups {
            let sizes = octantData4096Pointer[i].sizes
            
            if any(sizes.lower .> 0) { octantOffsets4096Pointer[i].lowerMarks &+= lowerOffsets }
            if any(sizes.upper .> 0) { octantOffsets4096Pointer[i].upperMarks &+= upperOffsets }
        }
        
        computeEncoder.setBuffer(destinationVertexBuffer, offset: 0, index: 9)
        computeEncoder.dispatchThreadgroups([ (preCullVertexCount + 15) >> 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()
        
        commandBuffer2.commit()
        
        
        
        let largestSize_intermediateValues1 = simd_max(lowerSizes, upperSizes)
        let largestSize_intermediateValues2 = simd_max(largestSize_intermediateValues1.lowHalf, largestSize_intermediateValues1.highHalf)
        secondSceneSorter.smallSectorSize = Float(1 << max(largestSize_intermediateValues2.x, largestSize_intermediateValues2.y))
        
        let nextNodes: [OctreeNode?] = [
            lowerCounts.x == 0 ? nil : OctreeNode(lowerCounts.x, lowerOffsets.x, Float(1 << lowerSizes.x) * [ 0.5,  0.5,  0.5, 1]),
            lowerCounts.y == 0 ? nil : OctreeNode(lowerCounts.y, lowerOffsets.y, Float(1 << lowerSizes.y) * [ 0.5,  0.5, -0.5, 1]),
            lowerCounts.z == 0 ? nil : OctreeNode(lowerCounts.z, lowerOffsets.z, Float(1 << lowerSizes.z) * [ 0.5, -0.5,  0.5, 1]),
            lowerCounts.w == 0 ? nil : OctreeNode(lowerCounts.w, lowerOffsets.w, Float(1 << lowerSizes.w) * [ 0.5, -0.5, -0.5, 1]),
            
            upperCounts.x == 0 ? nil : OctreeNode(upperCounts.x, upperOffsets.x, Float(1 << upperSizes.x) * [-0.5,  0.5,  0.5, 1]),
            upperCounts.y == 0 ? nil : OctreeNode(upperCounts.y, upperOffsets.y, Float(1 << upperSizes.y) * [-0.5,  0.5, -0.5, 1]),
            upperCounts.z == 0 ? nil : OctreeNode(upperCounts.z, upperOffsets.z, Float(1 << upperSizes.z) * [-0.5, -0.5,  0.5, 1]),
            upperCounts.w == 0 ? nil : OctreeNode(upperCounts.w, upperOffsets.w, Float(1 << upperSizes.w) * [-0.5, -0.5, -0.5, 1])
        ]
        
        sceneSorter.firstNode = OctreeNode(count: newVertexCapacity, offset: 0, nextNodes: nextNodes)
        sceneSorter.firstNode.expandToSize(secondSceneSorter.smallSectorSize)
        sceneSorter.octreeAsArray = firstNode.array
        
        sceneSorter.worldOctantSize = secondSceneSorter.smallSectorSize
    }
    
}

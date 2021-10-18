//
//  SceneMeshMatcherExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

extension SceneMeshMatcher {
    
    func prepareForFirstMatch() {
        swap(&oldSmallSectorBuffer, &newSmallSectorBuffer)
        
        ensureBufferCapacity(type: .smallSector, capacity: octreeAsArray.count)
        ensureBufferCapacity(type: .microSector, capacity: numMicroSectors)
        
        debugLabel {
            oldSmallSectorBuffer.label = "Old " + SmallSectorLayer.bufferLabel
            newSmallSectorBuffer.label = "New " + SmallSectorLayer.bufferLabel
        }
        
        
        
        if hashToMappingsArray != nil {
            shouldDoMatch = true
            hashToMappingsArray.removeAll(keepingCapacity: true)
        } else {
            hashToMappingsArray = []
        }
        
        let newSmallSectorHashesPointer = newSmallSectorBuffer[.hashes].assumingMemoryBound(to: UInt32.self)
        
        for i in 0..<octreeAsArray.count {
            var center = octreeAsArray[i].node.center
            center = fma(center, .init(repeating: 0.5), .init(repeating: -0.5))
            
            var hashVector = unsafeBitCast(simd_int3(center), to: simd_uint3.self)
            hashVector = [2047, 2047, 1023] & hashVector
            hashVector = hashVector &<< [21, 10, 0]
            
            let hash = hashVector.x | hashVector.y | hashVector.z
            hashToMappingsArray.append((hash, UInt16(i)))
            newSmallSectorHashesPointer[i] = hash
        }
        
        hashToMappingsArray = hashToMappingsArray.sorted{ $0.0 < $1.0 }
        
        let newSortedHashesPointer       = newSmallSectorBuffer[.sortedHashes].assumingMemoryBound(to: UInt32.self)
        let newSortedHashMappingsPointer = newSmallSectorBuffer[.sortedHashMappings].assumingMemoryBound(to: UInt16.self)

        for i in 0..<hashToMappingsArray.count {
            let arrayElement = hashToMappingsArray[i]

            newSortedHashesPointer[i]       = arrayElement.0
            newSortedHashMappingsPointer[i] = arrayElement.1
        }
        
        
        
        let numNewSmallSectorsPointer = newSmallSectorBuffer[.numSectorsMinus1].assumingMemoryBound(to: UInt16.self)
        numNewSmallSectorsPointer.pointee = UInt16(hashToMappingsArray.count) - 1
        
        let preCullVertexCountPointer = newSmallSectorBuffer[.preCullVertexCount].assumingMemoryBound(to: UInt32.self)
        preCullVertexCountPointer.pointee = UInt32(preCullVertexCount)
        
        ensureBufferCapacity(type: .vertex,   capacity: preCullVertexCount)
        ensureBufferCapacity(type: .triangle, capacity: preCullTriangleCount)
    }
    
    func initializeOldBuffers() {
        let newMicroSector512thBuffer = thirdSceneSorter.microSector512thBuffer
        let newNanoSector512thBuffer  = fourthSceneSorter.nanoSector512thBuffer
        let newVertexMapBuffer        = sceneDuplicateRemover.vertexMapBuffer
        let newComparisonIDBuffer     = fourthSceneSorter.destinationVertexBuffer
        
        oldMicroSector512thBuffer = device.makeLayeredBuffer(capacity: newMicroSector512thBuffer.capacity)
        oldNanoSector512thBuffer  = device.makeLayeredBuffer(capacity: newNanoSector512thBuffer.capacity, options: .storageModeShared)
        oldVertexMapBuffer        = device.makeLayeredBuffer(capacity: newVertexMapBuffer.capacity)
        oldComparisonIDBuffer     = device.makeBuffer(length: newComparisonIDBuffer.length, options: .storageModePrivate)!
        
        thirdSceneSorter.microSector512thBuffer   = oldMicroSector512thBuffer
        fourthSceneSorter.nanoSector512thBuffer   = oldNanoSector512thBuffer
        sceneDuplicateRemover.vertexMapBuffer     = oldVertexMapBuffer
        fourthSceneSorter.destinationVertexBuffer = oldComparisonIDBuffer
        
        oldComparisonIDBuffer.optLabel = newComparisonIDBuffer.optLabel
        
        oldMicroSector512thBuffer = newMicroSector512thBuffer
        oldNanoSector512thBuffer  = newNanoSector512thBuffer
        oldVertexMapBuffer        = newVertexMapBuffer
        oldComparisonIDBuffer     = newComparisonIDBuffer
        
        debugLabel {
            oldMicroSector512thBuffer.label = "(Old) " + oldMicroSector512thBuffer.label!
            oldNanoSector512thBuffer.label  = "(Old) " + oldNanoSector512thBuffer.label!
            oldVertexMapBuffer.label        = "(Old) " + oldVertexMapBuffer.label!
            oldComparisonIDBuffer.label!    = "(Old) " + oldComparisonIDBuffer.label!
        }
    }
    
    func checkOldBufferSizes() {
        let newMicroSector512thBuffer = thirdSceneSorter.microSector512thBuffer
        let newNanoSector512thBuffer  = fourthSceneSorter.nanoSector512thBuffer
        let newVertexMapBuffer        = sceneDuplicateRemover.vertexMapBuffer
        let newComparisonIDBuffer     = fourthSceneSorter.destinationVertexBuffer
        
        debugLabel {
            swap(&newMicroSector512thBuffer.label,  &oldMicroSector512thBuffer.label)
            swap(&newNanoSector512thBuffer .label,  &oldNanoSector512thBuffer .label)
            swap(&newVertexMapBuffer       .label,  &oldVertexMapBuffer       .label)
            swap(&newComparisonIDBuffer    .label!, &oldComparisonIDBuffer    .label!)
        }
        
        oldMicroSector512thBuffer.ensureCapacity(device: device, capacity: newMicroSector512thBuffer.capacity)
        oldNanoSector512thBuffer .ensureCapacity(device: device, capacity: newNanoSector512thBuffer.capacity)
        oldVertexMapBuffer       .ensureCapacity(device: device, capacity: newVertexMapBuffer.capacity)
        
        if oldComparisonIDBuffer.length < newComparisonIDBuffer.length {
            let oldLabel = oldComparisonIDBuffer.optLabel
            oldComparisonIDBuffer = device.makeBuffer(length: newComparisonIDBuffer.length, options: .storageModePrivate)!
            oldComparisonIDBuffer.optLabel = oldLabel
        }
        
        thirdSceneSorter.microSector512thBuffer   = oldMicroSector512thBuffer
        fourthSceneSorter.nanoSector512thBuffer   = oldNanoSector512thBuffer
        sceneDuplicateRemover.vertexMapBuffer     = oldVertexMapBuffer
        fourthSceneSorter.destinationVertexBuffer = oldComparisonIDBuffer
        
        oldMicroSector512thBuffer = newMicroSector512thBuffer
        oldNanoSector512thBuffer  = newNanoSector512thBuffer
        oldVertexMapBuffer        = newVertexMapBuffer
        oldComparisonIDBuffer     = newComparisonIDBuffer
    }
    
}

extension SceneMeshMatcher: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case smallSector
        case microSector
        case superNanoSector
        case nanoSector
        
        case vertex
        case vertexMatch
        case triangle
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .smallSector:     newSmallSectorBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .microSector:     oldMicroSectorBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .superNanoSector: nanoSectorColorAlias.ensureCapacity(device: device, capacity: newCapacity >> 2)
        case .nanoSector:      nanoSectorColorAlias.ensureCapacity(device: device, capacity: newCapacity << 1)
        
        case .vertex:          vertexMatchBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .vertexMatch:     ensureVertexMatchCapacity(capacity: newCapacity)
        case .triangle:        ensureTriangleCapacity(capacity: newCapacity)
        }
    }
    
    private func ensureVertexMatchCapacity(capacity: Int) {
        let newToOldVertexMatchesBufferSize = capacity * MemoryLayout<UInt32>.stride
        if newToOldVertexMatchesBuffer.length < newToOldVertexMatchesBufferSize {
            newToOldVertexMatchesBuffer = device.makeBuffer(length: newToOldVertexMatchesBufferSize, options: .storageModePrivate)!
            newToOldVertexMatchesBuffer.optLabel = "Scene Mesh Reduced New To Old Vertex Matches Buffer"
        }
    }
    
    private func ensureTriangleCapacity(capacity: Int) {
        let newToOldMatchWindingBufferSize = capacity * MemoryLayout<UInt8>.stride
        if newToOldMatchWindingBuffer.length < newToOldMatchWindingBufferSize {
            newToOldMatchWindingBuffer = device.makeBuffer(length: newToOldMatchWindingBufferSize, options: .storageModePrivate)!
            newToOldMatchWindingBuffer.optLabel = "Scene Mesh Matcher New To Old Match Winding Buffer"
        } else {
            return
        }
        
        let newToOldTriangleMatchesBufferSize = capacity * MemoryLayout<UInt32>.stride
        newToOldTriangleMatchesBuffer = device.makeBuffer(length: newToOldTriangleMatchesBufferSize, options: .storageModeShared)!
        newToOldTriangleMatchesBuffer.optLabel = "Scene Mesh Reducer New To Old Triangle Matches Buffer"
    }
    
}

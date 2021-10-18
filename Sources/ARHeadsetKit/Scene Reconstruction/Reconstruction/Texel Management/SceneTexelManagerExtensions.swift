//
//  SceneTexelManagerExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

extension SceneTexelManager {
    
    func swapBuffers() {
        swap(&oldTriangleMarkBuffer, &triangleMarkBuffer)
        
        debugLabel {
            triangleMarkBuffer.label    = "New " + TriangleMarkLayer.bufferLabel
            oldTriangleMarkBuffer.label = "Old " + TriangleMarkLayer.bufferLabel
        }
    }
    
    func synchronizeData() {
        oldTriangleCount = preCullTriangleCount
        
        sceneOcclusionTester.triangleMarkBuffer = triangleMarkBuffer
        sceneOcclusionTester.rasterizationComponentBuffer = newRasterizationComponentBuffer
        sceneMeshMatcher.oldRasterizationComponentBuffer = newRasterizationComponentBuffer
        
        sceneOcclusionTester.smallTriangleColorBuffer = smallTriangleColorBuffer
        sceneOcclusionTester.largeTriangleColorBuffer = largeTriangleColorBuffer
        
        sceneOcclusionTester.smallTriangleLumaTexture = smallTriangleLumaTexture
        sceneOcclusionTester.largeTriangleLumaTexture = largeTriangleLumaTexture
        sceneOcclusionTester.smallTriangleChromaTexture = smallTriangleChromaTexture
        sceneOcclusionTester.largeTriangleChromaTexture = largeTriangleChromaTexture
        
        sceneOcclusionTester.triangleDataBuffer = newTriangleDataBuffer
        sceneOcclusionTester.expandedColumnOffsetBuffer = sceneTexelRasterizer.expandedColumnOffsetBuffer
    }
    
}

extension SceneTexelManager: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case triangle
        case smallTriangle
        case largeTriangle
        
        case smallTriangleSlot
        case largeTriangleSlot
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .triangle:          ensureTriangleCapacity(capacity: newCapacity)
        case .smallTriangle:     ensureSmallTriangleCapacity(capacity: capacity)
        case .largeTriangle:     ensureLargeTriangleCapacity(capacity: capacity)
        
        case .smallTriangleSlot: smallTriangleSlotBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .largeTriangleSlot: largeTriangleSlotBuffer.ensureCapacity(device: device, capacity: newCapacity)
        }
    }
    
    private func ensureTriangleCapacity(capacity: Int) {
        bridgeBuffer      .ensureCapacity(device: device, capacity: capacity)
        triangleMarkBuffer.ensureCapacity(device: device, capacity: capacity)
    }
    
    private func ensureSmallTriangleCapacity(capacity: Int) {
        let targetCapacity = ~16383 & (capacity + 16383)
        let smallTriangleLumaTextureHeight = targetCapacity >> 6 - targetCapacity >> 9
        
        guard smallTriangleLumaTexture.height < smallTriangleLumaTextureHeight else {
            return
        }
        
        let oldSmallTriangleColorBuffer   = smallTriangleColorBuffer
        let oldSmallTriangleChromaTexture = smallTriangleChromaTexture
        smallTriangleColorBuffer = device.makeLayeredBuffer(capacity: smallTriangleLumaTextureHeight)
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.storageMode = .private
        
        textureDescriptor.width = 16384
        textureDescriptor.height = smallTriangleLumaTextureHeight
        textureDescriptor.pixelFormat = .r8Unorm
        smallTriangleLumaTexture = smallTriangleColorBuffer.makeTexture(descriptor: textureDescriptor, layer: .luma,
                                                                        bytesPerRow: 16384 * MemoryLayout<UInt8>.stride)
        smallTriangleLumaTexture.optLabel = "Scene Small Triangle Luma Texture"
        
        textureDescriptor.width = 8192
        textureDescriptor.height = smallTriangleLumaTextureHeight >> 1
        textureDescriptor.pixelFormat = .rg8Unorm
        smallTriangleChromaTexture = smallTriangleColorBuffer.makeTexture(descriptor: textureDescriptor, layer: .chroma,
                                                                          bytesPerRow: 8192 * MemoryLayout<simd_uchar2>.stride)
        smallTriangleChromaTexture.optLabel = "Scene Small Triangle Chroma Texture"
        
        
        
        let dispatchSize = 16384 * (8 * 7) / 8192
        let dispatchEnd = oldSmallTriangleChromaTexture.height
        
        var dispatchStart = 0
        var dispatchGroups: [[Dispatch]] = []
        
        while dispatchStart < dispatchEnd {
            let texelRowCount = min(dispatchSize, dispatchEnd - dispatchStart)
            dispatchGroups.append([ Dispatch(dispatchStart, texelRowCount) ])
            
            dispatchStart += dispatchSize
        }
        
        copyColor(oldColorBuffer: oldSmallTriangleColorBuffer,
                  newColorBuffer: smallTriangleColorBuffer, dispatchGroups: dispatchGroups)
    }
    
    private func ensureLargeTriangleCapacity(capacity: Int) {
        let targetCapacity = ~8191 & (capacity + 8191)
        let largeTriangleLumaTextureHeight = targetCapacity >> 4 - targetCapacity >> 7
        
        guard largeTriangleLumaTexture.height < largeTriangleLumaTextureHeight else {
            return
        }
        
        let oldLargeTriangleColorBuffer   = largeTriangleColorBuffer
        let oldLargeTriangleChromaTexture = largeTriangleChromaTexture
        largeTriangleColorBuffer = device.makeLayeredBuffer(capacity: largeTriangleLumaTextureHeight)
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.usage = [.shaderWrite, .shaderRead]
        textureDescriptor.storageMode = .private
        
        textureDescriptor.width = 16384
        textureDescriptor.height = largeTriangleLumaTextureHeight
        textureDescriptor.pixelFormat = .r8Unorm
        largeTriangleLumaTexture = largeTriangleColorBuffer.makeTexture(descriptor: textureDescriptor, layer: .luma,
                                                                        bytesPerRow: 16384 * MemoryLayout<UInt8>.stride)
        largeTriangleLumaTexture.optLabel = "Scene Large Triangle Luma Texture"
        
        textureDescriptor.width = 8192
        textureDescriptor.height = largeTriangleLumaTextureHeight >> 1
        textureDescriptor.pixelFormat = .rg8Unorm
        largeTriangleChromaTexture = largeTriangleColorBuffer.makeTexture(descriptor: textureDescriptor, layer: .chroma,
                                                                          bytesPerRow: 8192 * MemoryLayout<simd_uchar2>.stride)
        largeTriangleChromaTexture.optLabel = "Scene Large Triangle Chroma Texture"
        
        
        
        let triangleRowCount = oldLargeTriangleChromaTexture.height / 14
        
        let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Triangle Color Copying - Clear Row Height Buffer"
        
        let fillSize = triangleRowCount * 8 * MemoryLayout<UInt32>.stride
        blitEncoder.fill(buffer: colorCopyingRowHeightBuffer, layer: .mark, range: 0..<fillSize, value: 0)
        blitEncoder.endEncoding()
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Triangle Color Copying - Prepare Blit Pass"
        
        computeEncoder.setComputePipelineState(markColorCopyingRowSizesPipelineState)
        
        var copyingLargeTriangles = true
        computeEncoder.setBytes(&copyingLargeTriangles,                           length: 1, index: 0)
        computeEncoder.setBuffer(colorCopyingRowHeightBuffer,       layer: .mark,            index: 1)
        
        computeEncoder.setBuffer(oldTriangleMarkBuffer,             layer: .textureSlotID,   index: 2)
        computeEncoder.setBuffer(sceneTexelRasterizer.bridgeBuffer, layer: .matchExistsMark, index: 3)
        computeEncoder.setBuffer(oldRasterizationComponentBuffer,                 offset: 0, index: 4)
        computeEncoder.dispatchThreads([ numOldSmallTriangles + numOldLargeTriangles ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(reduceColorCopyingRowSizesPipelineState)
        computeEncoder.setBuffer(colorCopyingRowHeightBuffer, layer: .reducedSize, index: 2)
        computeEncoder.dispatchThreadgroups([ triangleRowCount ], threadsPerThreadgroup: 8)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
        
        var dispatchGroups: [[Dispatch]] = []
        var pendingDispatchGroup: [Dispatch] = []
        
        
        
        commandBuffer.waitUntilCompleted()
        let rowSizePointer = colorCopyingRowHeightBuffer[.reducedSize].assumingMemoryBound(to: UInt8.self)
        
        let dispatchSize = 4096 * (16 * 14) / 8192
        var groupDispatchSize = 0
        
        for i in 0..<triangleRowCount {
            let texelRowStart = i * 14
            let texelRowCount = Int(rowSizePointer[i])
            
            let nextDispatchSize = groupDispatchSize + texelRowCount
            
            if nextDispatchSize > dispatchSize {
                dispatchGroups.append(pendingDispatchGroup)
                pendingDispatchGroup = []
                
                groupDispatchSize = texelRowCount
            } else {
                groupDispatchSize = nextDispatchSize
            }
            
            pendingDispatchGroup.append(Dispatch(texelRowStart, texelRowCount))
        }
        
        if pendingDispatchGroup.count > 0 {
            dispatchGroups.append(pendingDispatchGroup)
        }
        
        copyColor(oldColorBuffer: oldLargeTriangleColorBuffer,
                  newColorBuffer: largeTriangleColorBuffer, dispatchGroups: dispatchGroups)
    }
    
    private typealias Dispatch = (texelRowStart: Int, texelRowCount: Int)
    
    private func copyColor<T>(oldColorBuffer: MTLLayeredBuffer<ColorLayer<T>>,
                              newColorBuffer: MTLLayeredBuffer<ColorLayer<T>>,
                              dispatchGroups: [[Dispatch]])
    {
        var previousCommandBuffer: MTLCommandBuffer?
        
        for dispatchGroup in dispatchGroups {
            let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
            
            debugLabel {
                let label = "Triangle \(T.self) Color Copying - Execute \(dispatchGroup.count) Dispatches"
                commandBuffer.label = label
                blitEncoder  .label = label
            }
            
            for dispatch in dispatchGroup {
                blitEncoder.pushOptDebugGroup("Execute Dispatch \(dispatch)")
                
                blitEncoder.copy(from: oldColorBuffer.buffer, sourceOffset:      dispatch.texelRowStart << 15,
                                 to:   newColorBuffer.buffer, destinationOffset: dispatch.texelRowStart << 15,
                                 size: dispatch.texelRowCount << 15)
                
                let sourceChromaOffset      = oldColorBuffer.offset(for: .chroma) + dispatch.texelRowStart << 14
                let destinationChromaOffset = newColorBuffer.offset(for: .chroma) + dispatch.texelRowStart << 14
                
                blitEncoder.copy(from: oldColorBuffer.buffer, sourceOffset:      sourceChromaOffset,
                                 to:   newColorBuffer.buffer, destinationOffset: destinationChromaOffset,
                                 size: dispatch.texelRowCount << 14)
                
                blitEncoder.popOptDebugGroup()
            }
            
            blitEncoder.endEncoding()
            
            previousCommandBuffer?.waitUntilCompleted()
            commandBuffer.commit()
            
            previousCommandBuffer = commandBuffer
        }
    }
    
}

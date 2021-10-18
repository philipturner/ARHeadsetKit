//
//  SceneDuplicateRemoverExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import simd

extension SceneDuplicateRemover {
    
    func swapMeshData() {
        swap(&reducedVertexBuffer, &finalVertexBuffer)
        swap(&reducedNormalBuffer, &finalNormalBuffer)
        swap(&reducedIndexBuffer,  &finalIndexBuffer)
        
        debugLabel {
            reducedVertexBuffer.label = "Scene Reduced Vertex Buffer (Pending)"
            finalVertexBuffer.label = "Scene Duplicate Remover Final Vertex Buffer"
            
            reducedNormalBuffer.label = "Scene Reduced Vertex Buffer (Pending)"
            finalNormalBuffer.label = "Scene Duplicate Remover Final Vertex Buffer"
            
            reducedIndexBuffer.label = "Scene Reduced Index Buffer (Pending)"
            finalIndexBuffer.label = "Scene Duplicate Remover Final Index Buffer"
        }
    }
    
}

extension SceneDuplicateRemover: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case vertex
        case triangle
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .vertex:   ensureVertexCapacity(capacity: newCapacity)
        case .triangle: ensureTriangleCapacity(capacity: newCapacity)
        }
        
        bridgeBuffer.ensureCapacity(device: device, capacity: newCapacity)
    }
    
    private func ensureVertexCapacity(capacity: Int) {
        vertexMapBuffer .ensureCapacity(device: device, capacity: capacity)
        vertexDataBuffer.ensureCapacity(device: device, capacity: capacity)
        
        let finalVertexBufferSize = capacity * MemoryLayout<simd_float3>.stride
        if finalVertexBuffer.length < finalVertexBufferSize {
            finalVertexBuffer = device.makeBuffer(length: finalVertexBufferSize, options: .storageModePrivate)!
            finalVertexBuffer.optLabel = "Scene Duplicate Remover Final Vertex Buffer"
            
            finalNormalBuffer = device.makeBuffer(length: finalVertexBufferSize >> 1, options: .storageModePrivate)!
            finalNormalBuffer.optLabel = "Scene Duplicate Remover Final Normal Buffer"
        }
    }
    
    private func ensureTriangleCapacity(capacity: Int) {
        let triangleInclusionMarkBufferSize = capacity * MemoryLayout<UInt32>.stride
        if triangleInclusionMarkBuffer.length < triangleInclusionMarkBufferSize {
            triangleInclusionMarkBuffer = device.makeBuffer(length: triangleInclusionMarkBufferSize, options: .storageModePrivate)!
            triangleInclusionMarkBuffer.optLabel = "Scene Duplicate Remover Triangle Inclusion Mark Buffer"
        }
        
        let finalIndexBufferSize = capacity * MemoryLayout<simd_uint3>.stride
        if finalIndexBuffer.length < finalIndexBufferSize {
            finalIndexBuffer = device.makeBuffer(length: finalIndexBufferSize, options: .storageModePrivate)!
            finalIndexBuffer.optLabel = "Scene Duplicate Remover Final Index Buffer"
        }
    }
    
}

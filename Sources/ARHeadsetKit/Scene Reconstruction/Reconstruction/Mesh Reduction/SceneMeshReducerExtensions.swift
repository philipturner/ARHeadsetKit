//
//  SceneMeshReducerExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import Metal
import ARKit

extension SceneMeshReducer {
    
    func updateResources(frame: ARFrame) {
        if meshUpdateCounter < meshUpdateRate {
            shouldUpdateMesh = false
        } else {
            let newSubmeshes = frame.anchors.compactMap{ $0 as? ARMeshAnchor }
            let submeshesAreEqual = submeshes.elementsEqual(newSubmeshes) {
                $0.geometry.vertices.buffer === $1.geometry.vertices.buffer
            }
            
            guard newSubmeshes.count > 0, !submeshesAreEqual || SceneRenderer.profilingSceneReconstruction else {
                shouldUpdateMesh = false
                return
            }
            
            sceneRenderer.currentlyMatchingMeshes = true
            shouldUpdateMesh = true
            
            meshUpdateCounter = 0
            submeshes = newSubmeshes
        }
    }
    
    func synchronizeData() {
        sceneRenderer.preCullVertexCount   = preCullVertexCount
        sceneRenderer.preCullTriangleCount = preCullTriangleCount
        
        sceneRenderer.meshToWorldTransform = meshToWorldTransform
        sceneCuller.octreeNodeCenters = sceneSorter.octreeAsArray.map{ $0.node.center }
        
        
        
        swap(&currentReducedVertexBuffer, &pendingReducedVertexBuffer)
        swap(&currentReducedNormalBuffer, &pendingReducedNormalBuffer)
        
        sceneRenderer.reducedVertexBuffer = currentReducedVertexBuffer
        sceneRenderer.reducedNormalBuffer = currentReducedNormalBuffer
        
        currentReducedVertexBuffer.optLabel = "Scene Reduced Vertex Buffer (Current)"
        pendingReducedVertexBuffer.optLabel = "Scene Reduced Vertex Buffer (Pending)"
            
        currentReducedNormalBuffer.optLabel = "Scene Reduced Normal Buffer (Current)"
        pendingReducedNormalBuffer.optLabel = "Scene Reduced Normal Buffer (Pending)"
        
        
        
        swap(&currentReducedColorBuffer, &pendingReducedColorBuffer)
        swap(&currentReducedIndexBuffer, &pendingReducedIndexBuffer)
        swap(&currentSectorIDBuffer,     &pendingSectorIDBuffer)
        
        sceneRenderer.reducedColorBuffer = currentReducedColorBuffer
        sceneRenderer.reducedIndexBuffer = currentReducedIndexBuffer
        
        currentReducedColorBuffer.optLabel = "Scene Reduced Color Buffer (Current)"
        pendingReducedColorBuffer.optLabel = "Scene Reduced Color Buffer (Pending)"
        
        currentReducedIndexBuffer.optLabel = "Scene Reduced Index Buffer (Current)"
        pendingReducedIndexBuffer.optLabel = "Scene Reduced Index Buffer (Pending)"
        
        currentSectorIDBuffer.optLabel = "Scene Mesh Reducer Sector ID Buffer (Current)"
        pendingSectorIDBuffer.optLabel = "Scene Mesh Reducer Sector ID Buffer (Pending)"
        
        
        
        sceneRenderer.ensureBufferCapacity(type: .vertex,   capacity: preCullVertexCount)
        sceneRenderer.ensureBufferCapacity(type: .triangle, capacity: preCullTriangleCount)
        
        sceneCuller.ensureBufferCapacity(type: .sector,   capacity: sceneSorter.octreeAsArray.count)
        sceneCuller.ensureBufferCapacity(type: .vertex,   capacity: preCullVertexCount)
        sceneCuller.ensureBufferCapacity(type: .triangle, capacity: preCullTriangleCount)
        
        sceneOcclusionTester.ensureBufferCapacity(type: .triangle, capacity: preCullTriangleCount)
    }
    
}

extension SceneMeshReducer: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case mesh
        case vertex
        case triangle
        case sectorID
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .mesh:     uniformBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .vertex:   ensureVertexCapacity(capacity: newCapacity)
        case .triangle: ensureTriangleCapacity(capacity: newCapacity)
        case .sectorID: ensureSectorIDCapacity(capacity: newCapacity)
        }
    }
    
    private func ensureVertexCapacity(capacity: Int) {
        let reducedVertexBufferSize = capacity * MemoryLayout<simd_float3>.stride
        if pendingReducedVertexBuffer.length < reducedVertexBufferSize {
            pendingReducedVertexBuffer = device.makeBuffer(length: reducedVertexBufferSize, options: .storageModePrivate)!
            pendingReducedVertexBuffer.optLabel = "Scene Reduced Vertex Buffer (Pending)"
            
            let reducedNormalBufferSize = reducedVertexBufferSize >> 1
            pendingReducedNormalBuffer = device.makeBuffer(length: reducedNormalBufferSize, options: .storageModePrivate)!
            pendingReducedNormalBuffer.optLabel = "Scene Reduced Normal Buffer (Pending)"
        }
        
        bridgeBuffer.ensureCapacity(device: device, capacity: capacity)
    }
    
    private func ensureTriangleCapacity(capacity: Int) {
        let reducedIndexBufferSize = capacity * MemoryLayout<simd_uint3>.stride
        if pendingReducedIndexBuffer.length < reducedIndexBufferSize {
            pendingReducedIndexBuffer = device.makeBuffer(length: reducedIndexBufferSize, options: .storageModePrivate)!
            pendingReducedIndexBuffer.optLabel = "Scene Reduced Index Buffer (Pending)"
        }
        
        let reducedColorBufferSize = capacity * MemoryLayout<simd_uint4>.stride
        if pendingReducedColorBuffer.length < reducedColorBufferSize {
            pendingReducedColorBuffer = device.makeBuffer(length: reducedColorBufferSize, options: .storageModePrivate)!
            pendingReducedColorBuffer.optLabel = "Scene Reduced Color Buffer (Pending)"
        }
    }
    
    private func ensureSectorIDCapacity(capacity: Int) {
        let transientSectorIDBufferSize = capacity * MemoryLayout<UInt8>.stride
        if transientSectorIDBuffer.length < transientSectorIDBufferSize {
            transientSectorIDBuffer = device.makeBuffer(length: transientSectorIDBufferSize, options: .storageModePrivate)!
            transientSectorIDBuffer.optLabel = "Scene Mesh Reducer Transient Sector ID Buffer"
        }
        
        pendingSectorIDBuffer.ensureCapacity(device: device, capacity: capacity)
    }
    
}

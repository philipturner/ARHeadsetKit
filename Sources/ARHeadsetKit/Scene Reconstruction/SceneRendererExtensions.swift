//
//  SceneRendererExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import ARKit

extension SceneRenderer: GeometryRenderer {
    
    func asyncUpdateResources(frame: ARFrame) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            updateResources(frame: frame)
            updateResourcesSemaphore.signal()
            
            if usingHeadsetMode, !usingVertexAmplification, shouldRenderToDisplay {
                updateResourcesSemaphore.signal()
            }
        }
    }
    
    func updateResources(frame: ARFrame) {
        sceneMeshReducer.meshUpdateCounter += 1
        sceneMeshReducer.shouldUpdateMesh = false
        colorSampleCounter += 1
        
        var canDoColorUpdate = false
        
        if !currentlyMatchingMeshes {
            if justCompletedMatching {
                justCompletedMatching = false
                colorSampleCounter = 100_000_000
                
                sceneTexelManager.transferColorDataToTexture()
                sceneMeshReducer.synchronizeData()
                sceneTexelManager.synchronizeData()
                
            } else if completedMatchingBeforeLastFrame {
                completedMatchingBeforeLastFrame = false
                
            } else if !SceneRenderer.profilingSceneReconstruction {
                sceneMeshReducer.updateResources(frame: frame)
                canDoColorUpdate = !sceneMeshReducer.shouldUpdateMesh
            }
            
            if SceneRenderer.profilingSceneReconstruction {
                sceneMeshReducer.updateResources(frame: frame)
                canDoColorUpdate = true
            }
        }
        
        doingRendering = preCullVertexCount ?? 0 > 0 && preCullTriangleCount ?? 0 > 0 && preCullTriangleCount >= preCullVertexCount
        
        guard doingRendering else {
            segmentationTextureSemaphore.wait()
            colorTextureSemaphore.wait()
            return
        }
        
        let vertexUniformPointer = uniformBuffer[.vertexUniform].assumingMemoryBound(to: VertexUniforms.self)
        vertexUniformPointer[renderIndex] = VertexUniforms(sceneRenderer: self, camera: frame.camera)
        
        if usingHeadsetMode {
            let headsetModeUniformPointer = uniformBuffer[.headsetModeUniform].assumingMemoryBound(to: HeadsetModeUniforms.self)
            headsetModeUniformPointer[renderIndex] = HeadsetModeUniforms(sceneRenderer: self)
        }
        
        let preCullVertexCountPointer = uniformBuffer[.preCullVertexCount].assumingMemoryBound(to: UInt32.self)
        preCullVertexCountPointer[renderIndex] = UInt32(preCullVertexCount)
        
        let preCullTriangleCountPointer = uniformBuffer[.preCullTriangleCount].assumingMemoryBound(to: UInt32.self)
        preCullTriangleCountPointer[renderIndex] = UInt32(preCullTriangleCount)
        
        
        
        let doingColorUpdate = canDoColorUpdate && colorSampleCounter >= colorSamplingRate
        
        sceneCuller.cullScene(doingColorUpdate: doingColorUpdate)
        sceneOcclusionTester.executeOcclusionTest()
        
        if doingColorUpdate, segmentationTexture != nil {
            colorSampleCounter = 0
            sceneOcclusionTester.executeColorUpdate()
        } else {
            colorTextureSemaphore.wait()
        }
    }
    
    enum GeometryType: CaseIterable {
        case sceneMesh
    }
    
    func drawGeometry(type: GeometryType, renderEncoder: ARMetalRenderCommandEncoder) {
        assert(shouldRenderToDisplay)
        guard doingRendering else { return }
        
        renderEncoder.pushOptDebugGroup("Render Scene")
        renderEncoder.setCullMode(usingFlyingMode ? .none : .back)
        
        if usingHeadsetMode {
            renderEncoder.encoder.setRenderPipelineState(headsetModeRenderPipelineState)
        } else if usingFlyingMode {
            renderEncoder.encoder.setRenderPipelineState(flyingModeRenderPipelineState)
        } else {
            renderEncoder.encoder.setRenderPipelineState(renderPipelineState)
        }
        
        renderEncoder.setVertexBuffer(vertexBuffer,                            layer: .renderVertex,    index: 0)
        renderEncoder.setVertexBuffer(vertexBuffer,                            layer: .videoFrameCoord, index: 1)
        renderEncoder.setVertexBuffer(sceneCuller.vertexDataBuffer,            layer: .renderOffset,    index: 2)
        
        renderEncoder.setVertexBuffer(triangleIDBuffer,                                      offset: 0, index: 3)
        renderEncoder.setVertexBuffer(reducedIndexBuffer,                                    offset: 0, index: 4)
        
        renderEncoder.setVertexBuffer(sceneOcclusionTester.triangleMarkBuffer, layer: .textureOffset,   index: 5)
        renderEncoder.setVertexBuffer(sceneOcclusionTester.rasterizationComponentBuffer,     offset: 0, index: 6)
        
        renderEncoder.setFragmentTexture(sceneOcclusionTester.triangleIDTexture,          index: 0)
        renderEncoder.setFragmentTexture(colorTextureY,                                   index: 1)
        renderEncoder.setFragmentTexture(colorTextureCbCr,                                index: 2)
        
        renderEncoder.setFragmentTexture(sceneOcclusionTester.smallTriangleLumaTexture,   index: 3)
        renderEncoder.setFragmentTexture(sceneOcclusionTester.largeTriangleLumaTexture,   index: 4)
        renderEncoder.setFragmentTexture(sceneOcclusionTester.smallTriangleChromaTexture, index: 5)
        renderEncoder.setFragmentTexture(sceneOcclusionTester.largeTriangleChromaTexture, index: 6)
        renderEncoder.drawPrimitives(type: .triangle, indirectBuffer: uniformBuffer, indirectBufferLayer: .triangleVertexCount)
        
        renderEncoder.popOptDebugGroup()
    }
    
    func updateMesh() {
        guard sceneMeshReducer.shouldUpdateMesh else { return }
        
        let updateMeshColor = { [unowned self] in
            sceneMeshReducer.reduceMeshes()
            sceneSorter.executeSceneSort()
            sceneDuplicateRemover.removeDuplicateVertices()
            
            sceneMeshMatcher.executeFirstMatch()
            sceneTexelRasterizer.rasterizeTexels()
            
            sceneMeshMatcher.executeSecondMatch()
            sceneTexelManager.classifyTriangleSizes()
            
            sceneMeshMatcher.executeThirdMatch()
            sceneTexelRasterizer.transferColorDataToBuffer()
            
            sceneMeshReducer.prepareOptimizedCulling()
            justCompletedMatching = true
            currentlyMatchingMeshes = false
        }
        
        if SceneRenderer.profilingSceneReconstruction {
            updateMeshColor()
        } else {
            DispatchQueue.global(qos: .utility).async(execute: updateMeshColor)
        }
    }
    
}

extension SceneRenderer: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case vertex
        case triangle
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .vertex:   vertexBuffer.ensureCapacity(device: device, capacity: newCapacity)
        case .triangle: ensureTriangleCapacity(capacity: newCapacity)
        }
    }
    
    private func ensureTriangleCapacity(capacity: Int) {
        let triangleIDBufferSize = capacity * MemoryLayout<UInt32>.stride
        if triangleIDBuffer.length < triangleIDBufferSize {
            triangleIDBuffer = device.makeBuffer(length: triangleIDBufferSize, options: .storageModePrivate)!
            triangleIDBuffer.optLabel = "Scene Triangle ID Buffer"
        }
    }
    
}
#endif

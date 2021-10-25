//
//  MainRenderingExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/11/21.
//

#if !os(macOS)
import Metal
import ARKit

extension MainRenderer {
    
    func update() {
        renderSemaphore.wait()
        
        guard let frame = session.currentFrame else {
            renderSemaphore.signal()
            return
        }
        
        updateResources(frame: frame)
        
        let commandBuffer = commandQueue.makeDebugCommandBuffer()
        commandBuffer.addCompletedHandler { _ in
            self.renderSemaphore.signal()
        }
        
        debugLabel {
            if usingVertexAmplification || !usingHeadsetMode {
                commandBuffer.label = "Render Command Buffer"
            } else {
                commandBuffer.label = "Render Command Buffer (Left)"
            }
        }
        
        if usingHeadsetMode {
            userSettings.lensDistortionCorrector.executeRenderPass(commandBuffer: commandBuffer)
        } else {
            let drawable = view.currentDrawable!
            
            if shouldRenderToDisplay {
                let renderPassDescriptor = MTLRenderPassDescriptor()
                renderPassDescriptor.colorAttachments[0].texture = msaaTexture
                renderPassDescriptor.colorAttachments[0].loadAction = .clear
                renderPassDescriptor.colorAttachments[0].storeAction = .multisampleResolve
                renderPassDescriptor.colorAttachments[0].resolveTexture = drawable.texture
                renderPassDescriptor.depthAttachment.texture = depthStencilTexture
                renderPassDescriptor.depthAttachment.clearDepth = 0
                renderPassDescriptor.stencilAttachment.texture = depthStencilTexture
                
                if interfaceRenderer.numRenderedElements == 0 {
                    renderPassDescriptor.stencilAttachment.loadAction = .dontCare
                }
                
                let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)!
                renderEncoder.optLabel = "Render Pass"
                renderEncoder.setFrontFacing(.counterClockwise)
                
                drawGeometry(renderEncoder: renderEncoder)
                renderEncoder.endEncoding()
            }
            
            commandBuffer.present(drawable)
        }
        
        if !shouldRenderToDisplay {
            if usingLiDAR, allowingSceneReconstruction {
                sceneRenderer.updateResourcesSemaphore.wait()
            } else {
                sceneRenderer2D.updateResourcesSemaphore.wait()
            }
        }
        
        if SceneRenderer.profilingSceneReconstruction, usingLiDAR, allowingSceneReconstruction {
            sceneRenderer.updateMesh()
        }
        
        commandBuffer.commit()
        
        if !SceneRenderer.profilingSceneReconstruction, usingLiDAR, allowingSceneReconstruction {
            sceneRenderer.updateMesh()
        }
    }
    
}
#endif

//
//  SceneRenderer2D.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/13/21.
//

#if !os(macOS)
import Metal
import simd

final class SceneRenderer2D: DelegateRenderer {
    unowned let renderer: MainRenderer
    
    var cameraPlaneDepth: Float = 2
    var segmentationTextureSemaphore = DispatchSemaphore(value: 0)
    var colorTextureSemaphore = DispatchSemaphore(value: 0)
    var updateResourcesSemaphore = DispatchSemaphore(value: 0)
    
    var renderPipelineState: ARMetalRenderPipelineState
    
    init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
        
        var descriptor = ARMetalRenderPipelineDescriptor(renderer: renderer)
        descriptor.vertexFunction = library.makeARVertexFunction(rendererName: "scene2D")
        descriptor.fragmentFunction = library.makeARFragmentFunction(name: "scene2D")
        descriptor.optLabel = "Scene 2D Render Pipeline"
        
        renderPipelineState = try! descriptor.makeRenderPipelineState()
    }
}

extension SceneRenderer2D: GeometryRenderer {
    
    func asyncUpdateResources(waitingOnSegmentationTexture: Bool) {
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            if waitingOnSegmentationTexture {
                segmentationTextureSemaphore.wait()
//                print("Signalled segmentation texture semaphore for 2D")
            } else {
//                print("Did not signal segmentation texture semaphore for 2D")
            }
            colorTextureSemaphore.wait()
            updateResourcesSemaphore.signal()
            
            if usingHeadsetMode, !usingVertexAmplification, shouldRenderToDisplay {
                updateResourcesSemaphore.signal()
            }
        }
    }
    
    enum GeometryType: CaseIterable {
        case sceneRectangle
    }
    
    func drawGeometry(type: GeometryType, renderEncoder: ARMetalRenderCommandEncoder) {
        assert(shouldRenderToDisplay)
        
        renderEncoder.pushOptDebugGroup("Render Scene (2D)")
        
        renderEncoder.setCullMode(usingFlyingMode ? .none : .back)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        
        var projectionTransforms = [simd_float4x4](unsafeUninitializedCount: 2)
        var projectionTransformsNumBytes: Int
        
        if usingHeadsetMode {
            projectionTransforms[0] = worldToLeftClipTransform  * cameraToWorldTransform
            projectionTransforms[1] = worldToRightClipTransform * cameraToWorldTransform
            projectionTransformsNumBytes = 2 * MemoryLayout<simd_float4x4>.stride
        } else {
            projectionTransforms[0] = worldToScreenClipTransform * cameraToWorldTransform
            projectionTransformsNumBytes = MemoryLayout<simd_float4x4>.stride
        }
        
        renderEncoder.setVertexBytes(&projectionTransforms, length: projectionTransformsNumBytes, index: 0)
        
        struct VertexUniforms {
            var imageBounds: simd_float2
            var cameraPlaneDepth: Float
            var usingFlyingMode: Bool
        }
        
        let pixelWidthHalf = Float(renderer.cameraMeasurements.currentPixelWidth) * 0.5
        let imageBounds = simd_float2(
            Float(imageResolution.width) * pixelWidthHalf,
            Float(imageResolution.height) * pixelWidthHalf
        )
        
        var vertexUniforms = VertexUniforms(imageBounds: imageBounds * cameraPlaneDepth,
                                            cameraPlaneDepth: -cameraPlaneDepth,
                                            usingFlyingMode: usingFlyingMode)
        
        renderEncoder.setVertexBytes(&vertexUniforms, length: MemoryLayout<VertexUniforms>.stride, index: 1)
        
        renderEncoder.setFragmentTexture(colorTextureY,    index: 0)
        renderEncoder.setFragmentTexture(colorTextureCbCr, index: 1)
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        renderEncoder.popOptDebugGroup()
    }
}
#endif

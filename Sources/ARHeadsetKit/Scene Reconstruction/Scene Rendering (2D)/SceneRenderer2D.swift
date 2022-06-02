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
    var colorTextureSemaphore = DispatchSemaphore(value: 0)
    var updateResourcesSemaphore = DispatchSemaphore(value: 0)
    
    var segmentationTextureSemaphore = DispatchSemaphore(value: 0)
    var usingSegmentationTexture: Bool?
    
    var renderPipelineState: ARMetalRenderPipelineState
    var renderPipelineState2: ARMetalRenderPipelineState // for mirroring hand
    
    init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
        
        var descriptor = ARMetalRenderPipelineDescriptor(renderer: renderer)
        descriptor.vertexFunction = library.makeARVertexFunction(rendererName: "scene2D")
        descriptor.fragmentFunction = library.makeARFragmentFunction(name: "scene2D")
        descriptor.optLabel = "Scene 2D Render Pipeline"
        
        renderPipelineState = try! descriptor.makeRenderPipelineState()
        
        do {
            let fragmentMTLFunction = library.makeFunction(name: "scene2DFragmentShader2")!
            descriptor.fragmentFunction = .init(fragmentMTLFunction)
        }
        descriptor.optLabel = "Scene 2D Render Pipeline 2"
        renderPipelineState2 = try! descriptor.makeRenderPipelineState()
    }
}

extension SceneRenderer2D: GeometryRenderer {
    
    func asyncUpdateResources(waitingOnSegmentationTexture: Bool) {
        usingSegmentationTexture = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            if waitingOnSegmentationTexture {
                segmentationTextureSemaphore.wait()
                usingSegmentationTexture = true
            } else {
                usingSegmentationTexture = false
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
        
        guard let usingSegmentationTexture = usingSegmentationTexture else {
            fatalError("Did not set `sceneRenderer2D.usingSegmentationTexture`.")
        }
        let pipelineState = usingSegmentationTexture ? renderPipelineState2 : renderPipelineState
        renderEncoder.setRenderPipelineState(pipelineState)
        
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
        if usingSegmentationTexture {
            renderEncoder.setFragmentTexture(segmentationTexture, index: 2)
        }
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        
        renderEncoder.popOptDebugGroup()
    }
}
#endif

//
//  InterfaceRenderer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/28/21.
//

import Metal
import simd

protocol InterfaceVertexUniforms {
    init(interfaceRenderer: InterfaceRenderer, alias: ARInterfaceElement.Alias)
}

public final class InterfaceRenderer: DelegateRenderer {
    public unowned let renderer: MainRenderer
    var fontHandles: [FontHandle] { Self.fontHandles }
    
    var numRenderedElements = -1
    var opaqueAliases: [ARInterfaceElement.Alias] = []
    var transparentAliases: [ARInterfaceElement.Alias] = []
    
    var opaqueElementGroupCounts: [Int] = []
    var transparentElementGroupCounts: [Int] = []
    
    struct VertexUniforms: InterfaceVertexUniforms {
        var projectionTransform: simd_float4x4
        var eyeDirectionTransform: simd_float4x4
        var normalTransform: simd_half3x3
        
        var controlPoints: simd_float4x2
        
        init(interfaceRenderer: InterfaceRenderer, alias: ARInterfaceElement.Alias) {
            let modelToWorldTransform = alias.modelToWorldTransform
            projectionTransform = interfaceRenderer.worldToScreenClipTransform * modelToWorldTransform
            eyeDirectionTransform = (-modelToWorldTransform).appendingTranslation(interfaceRenderer.handheldEyePosition)
            
            normalTransform = alias.normalTransform
            controlPoints = alias.controlPoints
        }
    }
    
    struct HeadsetModeUniforms: InterfaceVertexUniforms {
        var leftProjectionTransform: simd_float4x4
        var rightProjectionTransform: simd_float4x4
        
        var leftEyeDirectionTransform: simd_float4x4
        var rightEyeDirectionTransform: simd_float4x4
        var normalTransform: simd_half3x3
        
        var controlPoints: simd_float4x2
        
        init(interfaceRenderer: InterfaceRenderer, alias: ARInterfaceElement.Alias) {
            let modelToWorldTransform = alias.modelToWorldTransform
            leftProjectionTransform  = interfaceRenderer.worldToLeftClipTransform  * modelToWorldTransform
            rightProjectionTransform = interfaceRenderer.worldToRightClipTransform * modelToWorldTransform
            
            leftEyeDirectionTransform  = (-modelToWorldTransform).appendingTranslation(interfaceRenderer.leftEyePosition)
            rightEyeDirectionTransform = (-modelToWorldTransform).appendingTranslation(interfaceRenderer.rightEyePosition)
            
            normalTransform = alias.normalTransform
            controlPoints = alias.controlPoints
        }
    }
    
    struct FragmentUniforms {
        var surfaceColor: simd_packed_half3
        var surfaceShininess: Float16
        
        var textColor: simd_half3
        var textShininess: Float16
        var textOpacity: Float16
        
        init(interfaceElement: ARInterfaceElement) {
            surfaceColor = .init(interfaceElement.surfaceColor)
            surfaceShininess   = interfaceElement.surfaceShininess
            
            textColor     = interfaceElement.textColor
            textShininess = interfaceElement.textShininess
            textOpacity   = interfaceElement.textOpacity
        }
    }
    
    enum UniformLayer: UInt16, MTLBufferLayer {
        case vertexUniform
        case fragmentUniform
        
        case surfaceVertex
        case surfaceEyeDirection
        case surfaceNormal
        
        static let bufferLabel = "Interface Renderer Uniform Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .vertexUniform:       return capacity * MainRenderer.numRenderBuffers * MemoryLayout<HeadsetModeUniforms>.stride
            case .fragmentUniform:     return capacity * MainRenderer.numRenderBuffers * MemoryLayout<FragmentUniforms>.stride
            
            case .surfaceVertex:       return capacity * 272     * MemoryLayout<simd_float4>.stride
            case .surfaceEyeDirection: return capacity * 272     * MemoryLayout<simd_float3>.stride
            case .surfaceNormal:       return capacity * 272 / 2 * MemoryLayout<simd_half3>.stride
            }
        }
    }
    
    enum GeometryLayer: UInt16, MTLBufferLayer {
        case cornerNormal
        case surfaceVertexAttribute
        
        case surfaceIndex
        case textIndex
        
        static let bufferLabel = "Interface Renderer Geometry Buffer"
        
        func getSize(capacity _: Int) -> Int {
            switch self {
            case .cornerNormal:           return 32  * MemoryLayout<simd_half2>.stride
            case .surfaceVertexAttribute: return 536 * MemoryLayout<simd_ushort2>.stride
            
            case .surfaceIndex:           return 266 * 6 * MemoryLayout<UInt16>.stride
            case .textIndex:              return       6 * MemoryLayout<UInt16>.stride
            }
        }
    }
    
    var uniformBuffer: MTLLayeredBuffer<UniformLayer>
    var geometryBuffer: MTLLayeredBuffer<GeometryLayer>
    
    var vertexUniformOffset: Int { renderIndex * uniformBuffer.capacity * MemoryLayout<HeadsetModeUniforms>.stride }
    var fragmentUniformOffset: Int { renderIndex * uniformBuffer.capacity * MemoryLayout<FragmentUniforms>.stride }
    
    var createSurfaceMeshesPipelineState: MTLComputePipelineState
    var createHeadsetModeSurfaceMeshesPipelineState: MTLComputePipelineState
    
    var textRenderPipelineState: ARMetalRenderPipelineState
    var surfaceRenderPipelineState: ARMetalRenderPipelineState
    var clearStencilPipelineState: ARMetalRenderPipelineState
    var depthPassPipelineState: ARMetalRenderPipelineState
    var transparentSurfaceRenderPipelineState: ARMetalRenderPipelineState
    
    var textDepthStencilState: MTLDepthStencilState
    var surfaceDepthStencilState: MTLDepthStencilState
    var clearStencilDepthStencilState: MTLDepthStencilState
    var depthPassDepthStencilState: MTLDepthStencilState
    var transparentSurfaceDepthStencilState: MTLDepthStencilState
    
    public init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
        let device = renderer.device
        
        uniformBuffer  = device.makeLayeredBuffer(capacity: 8, options: [.cpuCacheModeWriteCombined, .storageModeShared])
        geometryBuffer = device.makeLayeredBuffer(capacity: 1, options: [.cpuCacheModeWriteCombined, .storageModeShared])
        
        let cornerNormalPointer = geometryBuffer[.cornerNormal].assumingMemoryBound(to: SIMD8<Float16>.self)
        
        for i in 0..<32 >> 2 {
            let indices = simd_uint4(repeating: UInt32(i << 2)) &+ simd_uint4(0, 1, 2, 3)
            let angles = simd_float4(indices) * (.pi / 2 / 32)
            
            let sines = sin(angles)
            let cosines = sqrt(fma(-sines, sines, 1))
            
            let output1 = simd_half4(simd_float4(cosines[0], sines[0], cosines[1], sines[1]))
            let output2 = simd_half4(simd_float4(cosines[2], sines[2], cosines[3], sines[3]))
            
            cornerNormalPointer[i] = .init(lowHalf: output1, highHalf: output2)
        }
        
        let surfaceMeshIndicesURL = Bundle.safeModule.url(forResource: "InterfaceSurfaceMeshIndices", withExtension: "data")!
        let surfaceMeshIndexData = try! Data(contentsOf: surfaceMeshIndicesURL)
        
        let vertexAttributeDestinationPointer = geometryBuffer[.surfaceVertexAttribute]
        let vertexAttributeSourcePointer = surfaceMeshIndexData.withUnsafeBytes{ $0.baseAddress! }
        let vertexAttributeBufferSize = GeometryLayer.surfaceVertexAttribute.getSize(capacity: 1)
        memcpy(vertexAttributeDestinationPointer, vertexAttributeSourcePointer, vertexAttributeBufferSize)
        
        let surfaceIndexDestinationPointer = geometryBuffer[.surfaceIndex]
        let surfaceIndexSourcePointer = vertexAttributeSourcePointer + vertexAttributeBufferSize
        let surfaceIndexBufferSize = GeometryLayer.surfaceIndex.getSize(capacity: 1)
        memcpy(surfaceIndexDestinationPointer, surfaceIndexSourcePointer, surfaceIndexBufferSize)
        
        let textIndexPointer = geometryBuffer[.textIndex].assumingMemoryBound(to: simd_uint3.self)
        textIndexPointer[0] = .init(unsafeBitCast(simd_ushort2(0, 1), to: UInt32.self),
                                    unsafeBitCast(simd_ushort2(2, 0), to: UInt32.self),
                                    unsafeBitCast(simd_ushort2(2, 3), to: UInt32.self))
        
        func makePipeline(name: String) -> MTLComputePipelineState { library.makeComputePipeline(Self.self, name: name) }
        createSurfaceMeshesPipelineState            = makePipeline(name: "createInterfaceSurfaceMeshes")
        createHeadsetModeSurfaceMeshesPipelineState = makePipeline(name: "createInterfaceVRSurfaceMeshes")
        
        
        
        do {
            var descriptor = ARMetalRenderPipelineDescriptor(renderer: renderer)
            descriptor.vertexFunction = library.makeARVertexFunction(rendererName: "interface", objectName: "Surface")
            descriptor.optLabel = "Interface Surface Render Pipeline"
            surfaceRenderPipelineState = try! descriptor.makeRenderPipelineState()
            
            descriptor.descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.descriptor.colorAttachments[0].sourceRGBBlendFactor = .blendAlpha
            descriptor.descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusBlendAlpha
            descriptor.optLabel = "Interface Transparent Surface Render Pipeline"
            transparentSurfaceRenderPipelineState = try! descriptor.makeRenderPipelineState()
            
            descriptor.vertexFunction   = library.makeARVertexFunction(rendererName: "interface", objectName: "Text")
            descriptor.fragmentFunction = library.makeARFragmentFunction(name: "interfaceText")
            descriptor.descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.optLabel = "Interface Text Render Pipeline"
            textRenderPipelineState = try! descriptor.makeRenderPipelineState()
            
            descriptor.vertexFunction = library.makeARVertexFunction(rendererName: "interface", objectName: "DepthPass")
            descriptor.descriptor.fragmentFunction = nil
            descriptor.optLabel = "Interface Depth Pass Pipeline"
            depthPassPipelineState = try! descriptor.makeRenderPipelineState_noFragment()
            
            let clearStencilFunction = library.makeFunction(name: "clearStencilVertexTransform")!
            descriptor.vertexFunction = ARMetalVertexFunction(clearStencilFunction, clearStencilFunction)
            descriptor.optLabel = "Clear Stencil Render Pipeline"
            clearStencilPipelineState = try! descriptor.makeRenderPipelineState_noFragment()
        }
        
        do {
            let descriptor = MTLDepthStencilDescriptor()
            descriptor.frontFaceStencil = .init()
            descriptor.frontFaceStencil.depthStencilPassOperation = .replace
            descriptor.optLabel = "Clear Stencil Depth-Stencil State"
            clearStencilDepthStencilState = device.makeDepthStencilState(descriptor: descriptor)!
            
            descriptor.depthCompareFunction = .equal
            descriptor.optLabel = "Transparent Surface Depth-Stencil State"
            transparentSurfaceDepthStencilState = device.makeDepthStencilState(descriptor: descriptor)!
            
            descriptor.depthCompareFunction = .greater
            descriptor.isDepthWriteEnabled = true
            descriptor.optLabel = "Interface Surface Depth-Stencil State"
            surfaceDepthStencilState = device.makeDepthStencilState(descriptor: descriptor)!
            
            descriptor.frontFaceStencil.stencilCompareFunction = .equal
            descriptor.depthCompareFunction = .always
            descriptor.isDepthWriteEnabled = false
            descriptor.optLabel = "Interface Text Depth-Stencil State"
            textDepthStencilState = device.makeDepthStencilState(descriptor: descriptor)!
            
            descriptor.frontFaceStencil = nil
            descriptor.depthCompareFunction = .greater
            descriptor.isDepthWriteEnabled = true
            descriptor.optLabel = "Depth Pass Depth-Stencil State"
            depthPassDepthStencilState = device.makeDepthStencilState(descriptor: descriptor)!
        }
        
        Self.fontHandles = Self.createFontHandles(device: device, commandQueue: renderer.commandQueue, library: library,
                                                  configurations: [
                                                      (name: "System Font Regular",  size: 144),
                                                      (name: "System Font Semibold", size: 144),
                                                      (name: "System Font Bold",     size: 144)
                                                  ])
    }
    
    deinit {
        Self.resetCachedTextData()
    }
}

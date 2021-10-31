//
//  CentralRenderer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/17/21.
//

#if !os(macOS)
import Metal
import simd

protocol CentralVertexUniforms {
    init(centralRenderer: CentralRenderer, alias: ARObject.Alias)
}

public final class CentralRenderer: DelegateRenderer {
    public unowned let renderer: MainRenderer
    
    var didSetRenderPipeline: simd_ulong2 = .zero
    public var currentlyCulling: simd_ulong2 = .zero
    
    // Use when determining whether to present an object
    public internal(set) var cullTransform = simd_float4x4(1)
    // Use when finding LOD in left-eye or monocular view
    public internal(set) var lodTransform = simd_float4x4(1)
    // Use when finding LOD in left-eye or monocular view
    public internal(set) var lodTransformInverse = simd_float4x4(1)
    
    // Use when finding LOD in right-eye view
    public internal(set) var lodTransform2 = simd_float4x4(1)
    // use when finding LOD in right-eye view
    public internal(set) var lodTransformInverse2 = simd_float4x4(1)
    
    private var circles: [UInt16 : [simd_float2]] = [:]
    func circle(numSegments: UInt16) -> [simd_float2] {
        if let circleVertices = circles[numSegments] {
            return circleVertices
        } else {
            let multiplier = 2 / Float(numSegments)
            
            let circleVertices = (0..<numSegments).map {
                __sincospif_stret(Float($0) * multiplier).sinCosVector * 0.5
            }
            
            circles[numSegments] = circleVertices
            
            return circleVertices
        }
    }
    
    struct VertexUniforms: CentralVertexUniforms {
        var projectionTransform: simd_float4x4
        var eyeDirectionTransform: simd_float4x4
        
        var normalTransform: simd_half3x3
        var truncatedConeTopScale: Float
        var truncatedConeNormalMultipliers: simd_half2
        
        init(centralRenderer: CentralRenderer, alias: ARObject.Alias) {
            projectionTransform = centralRenderer.worldToScreenClipTransform * alias.modelToWorldTransform
            eyeDirectionTransform = (-alias.modelToWorldTransform).appendingTranslation(centralRenderer.handheldEyePosition)
            
            normalTransform = alias.normalTransform
            truncatedConeTopScale = alias.truncatedConeTopScale
            truncatedConeNormalMultipliers = alias.truncatedConeNormalMultipliers
        }
    }
    
    struct HeadsetModeUniforms: CentralVertexUniforms {
        var leftProjectionTransform: simd_float4x4
        var rightProjectionTransform: simd_float4x4
        
        var leftEyeDirectionTransform: simd_float4x4
        var rightEyeDirectionTransform: simd_float4x4
        
        var normalTransform: simd_half3x3
        var truncatedConeTopScale: Float
        var truncatedConeNormalMultipliers: simd_half2
        
        init(centralRenderer: CentralRenderer, alias: ARObject.Alias) {
            leftProjectionTransform  = centralRenderer.worldToLeftClipTransform  * alias.modelToWorldTransform
            rightProjectionTransform = centralRenderer.worldToRightClipTransform * alias.modelToWorldTransform
            
            leftEyeDirectionTransform  = (-alias.modelToWorldTransform).appendingTranslation(centralRenderer.leftEyePosition)
            rightEyeDirectionTransform = (-alias.modelToWorldTransform).appendingTranslation(centralRenderer.rightEyePosition)
            
            normalTransform = alias.normalTransform
            truncatedConeTopScale = alias.truncatedConeTopScale
            truncatedConeNormalMultipliers = alias.truncatedConeNormalMultipliers
        }
    }
    
    struct GlobalFragmentUniforms {
        var ambientLightColor: simd_half3
        var ambientInsideLightColor: simd_half3
        
        var directionalLightColor: simd_half3
        var lightDirection: simd_half3
        
        init(centralRenderer: CentralRenderer) {
            let retrievedAmbientLightColor = centralRenderer.ambientLightColor
            ambientLightColor = retrievedAmbientLightColor
            ambientInsideLightColor = retrievedAmbientLightColor * 0.5
            
            directionalLightColor = centralRenderer.directionalLightColor
            lightDirection = centralRenderer.lightDirection
        }
    }
    
    struct FragmentUniforms {
        var modelColor: simd_packed_half3
        var shininess: Float16
        
        init(alias: ARObject.Alias) {
            modelColor = alias.color
            shininess = alias.shininess
        }
    }
    
    var shapeContainers: [CentralShapeContainer]
    
    var globalFragmentUniformBuffer: MTLBuffer
    var globalFragmentUniformOffset: Int { renderIndex * MemoryLayout<GlobalFragmentUniforms>.stride }
    
    var renderPipelineState: ARMetalRenderPipelineState
    var coneRenderPipelineState: ARMetalRenderPipelineState
    var cylinderRenderPipelineState: ARMetalRenderPipelineState
    
    public init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
        let device = renderer.device
        
        let globalFragmentUniformBufferSize = MainRenderer.numRenderBuffers * MemoryLayout<GlobalFragmentUniforms>.stride
        globalFragmentUniformBuffer = device.makeBuffer(length: globalFragmentUniformBufferSize, options: .storageModeShared)!
        globalFragmentUniformBuffer.optLabel = "Central Global Fragment Uniform Buffer"
        
        
        
        let vertexDescriptor = MTLVertexDescriptor()
        vertexDescriptor.layouts[0].stride = MemoryLayout<simd_float3>.stride
        vertexDescriptor.layouts[1].stride = MemoryLayout<simd_half3>.stride
        
        vertexDescriptor.attributes[0].format = .float3
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        vertexDescriptor.attributes[1].format = .half3
        vertexDescriptor.attributes[1].offset = 0
        vertexDescriptor.attributes[1].bufferIndex = 1
        
        vertexDescriptor.attributes[2].format = .ushort
        vertexDescriptor.attributes[2].offset = 6
        vertexDescriptor.attributes[2].bufferIndex = 1
        
        do {
            var descriptor = ARMetalRenderPipelineDescriptor(renderer: renderer)
            descriptor.fragmentFunction = library.makeARFragmentFunction(name: "central")
            descriptor.vertexDescriptor = vertexDescriptor
            
            descriptor.vertexFunction = library.makeARVertexFunction(rendererName: "central")
            descriptor.optLabel = "Central Render Pipeline"
            renderPipelineState = try! descriptor.makeRenderPipelineState()
            
            descriptor.vertexFunction = library.makeARVertexFunction(rendererName: "central", objectName: "ConeVertex")
            descriptor.optLabel = "Central Cone Render Pipeline"
            coneRenderPipelineState = try! descriptor.makeRenderPipelineState()
            
            descriptor.vertexFunction = library.makeARVertexFunction(rendererName: "central", objectName: "CylinderVertex")
            descriptor.optLabel = "Central Cylinder Render Pipeline"
            cylinderRenderPipelineState = try! descriptor.makeRenderPipelineState()
        }
            
        
        
        shapeContainers = Array(capacity: 6)
        
        shapeContainers.append(ShapeContainer<CentralCube>         (centralRenderer: self))
        shapeContainers.append(ShapeContainer<CentralSquarePyramid>(centralRenderer: self))
        shapeContainers.append(ShapeContainer<CentralOctahedron>   (centralRenderer: self))
        
        var shapeSizes = (3...11).map {
            Int(round(exp2(Float($0) * 0.5)))
        }
        
        shapeContainers.append(ShapeContainer<CentralSphere>(centralRenderer: self, range: shapeSizes))
        
        shapeSizes += (12...14).map {
            Int(round(exp2(Float($0) * 0.5)))
        }
        
        shapeContainers.append(ShapeContainer<CentralCone>    (centralRenderer: self, range: shapeSizes))
        shapeContainers.append(ShapeContainer<CentralCylinder>(centralRenderer: self, range: shapeSizes))
        
        circles = [:]
    }
}
#endif

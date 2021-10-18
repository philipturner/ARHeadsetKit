//
//  ARInterfaceElementExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 9/27/21.
//

import simd

extension ARInterfaceElement {
    
    struct Alias {
        var modelToWorldTransform: simd_float4x4
        var normalTransform: simd_half3x3
        var controlPoints: simd_float4x2
        
        var characterGroups: [CharacterGroup?]
        var fragmentUniforms: InterfaceRenderer.FragmentUniforms
        var surfaceOpacity: Float
        
        init(interfaceElement: ARInterfaceElement) {
            modelToWorldTransform = interfaceElement.makeModelToWorldTransform()
            normalTransform = interfaceElement.normalTransform
            controlPoints = interfaceElement.controlPoints
            
            characterGroups = interfaceElement.characterGroups
            fragmentUniforms = .init(interfaceElement: interfaceElement)
            surfaceOpacity = interfaceElement.surfaceOpacity
        }
    }
    
    var alias: Alias { Alias(interfaceElement: self) }
    
}

extension ARInterfaceElement: RayTraceable {
    
    public func trace(ray worldSpaceRay: RayTracing.Ray) -> Float? {
        guard !hidden, let initialProgress = _object.trace(ray: worldSpaceRay) else {
            return nil
        }
        
        if radius == 0 { return initialProgress }
        
        var modelToWorldTransform = self.makeModelToWorldTransform()
        modelToWorldTransform[2] *= _inverseScale.z
        
        let worldToModelTransform = modelToWorldTransform.inverseRotationTranslation
        let worldSpaceIntersection = worldSpaceRay.project(progress: initialProgress)
        var modelSpaceIntersection = simd_make_float3(worldToModelTransform * simd_float4(worldSpaceIntersection, 1))
        
        let controlX = controlPoints[0][0]
        let controlY = controlPoints[1][0]
        
        if abs(modelSpaceIntersection.x) <= controlX ||
           abs(modelSpaceIntersection.y) <= controlY {
            return initialProgress
        }
        
        var modelSpaceOrigin = simd_make_float3(worldToModelTransform * simd_float4(worldSpaceRay.origin, 1))
        modelSpaceOrigin       = .init(modelSpaceOrigin.x,       modelSpaceOrigin.z,       modelSpaceOrigin.y)
        modelSpaceIntersection = .init(modelSpaceIntersection.x, modelSpaceIntersection.z, modelSpaceIntersection.y)
        
        let radiusMultiplier = _inverseScale.w * 0.5
        let rayScaleMultiplier = simd_float3(radiusMultiplier, _inverseScale.z, radiusMultiplier)
        let rayDirection = (modelSpaceIntersection - modelSpaceOrigin) * rayScaleMultiplier
        
        var finalProgress = Float.greatestFiniteMagnitude
        
        func testCorner(x: Float, z: Float) {
            let rayOrigin = (modelSpaceOrigin - simd_float3(x, 0, z)) * rayScaleMultiplier
            let testRay = RayTracing.Ray(origin: rayOrigin, direction: rayDirection)
            guard testRay.passesInitialBoundingBoxTest() else { return }
            
            if let testProgress = testRay.getCentralCylinderProgress(), testProgress < finalProgress {
                finalProgress = testProgress
            }
        }
        
        func testSide(x: Float) {
            if modelSpaceIntersection.z > controlY || controlY <= 1e-8 {
                testCorner(x: x, z: controlY)
            }
            
            if modelSpaceIntersection.z < -controlY, controlY > 1e-8 {
                testCorner(x: x, z: -controlY)
            }
        }
        
        if modelSpaceIntersection.x > controlX || controlX <= 1e-8 {
            testSide(x: controlX)
        }
        
        if modelSpaceIntersection.x < -controlX, controlX > 1e-8 {
            testSide(x: -controlX)
        }
        
        if finalProgress < .greatestFiniteMagnitude {
            return initialProgress * finalProgress
        } else {
            return nil
        }
    }
    
}

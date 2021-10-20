//
//  CentralRendererExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/19/21.
//

#if !os(macOS)
import Metal
import simd

public extension CentralRenderer {
    
    internal func initializeFrameData() {
        didSetRenderPipeline = .zero
        currentlyCulling = .zero
        
        for i in 0..<shapeContainers.count { shapeContainers[i].clearAliases() }
        
        if usingHeadsetMode {
            cullTransform = worldToHeadsetModeCullTransform
            
            if usingFlyingMode {
                lodTransform  = worldToFlyingPerspectiveTransform.appendingTranslation(-cameraSpaceLeftEyePosition)
                lodTransform2 = worldToFlyingPerspectiveTransform.appendingTranslation(-cameraSpaceRightEyePosition)
                
                lodTransformInverse  = flyingPerspectiveToWorldTransform.prependingTranslation(cameraSpaceLeftEyePosition)
                lodTransformInverse2 = flyingPerspectiveToWorldTransform.prependingTranslation(cameraSpaceRightEyePosition)
            } else {
                lodTransform  = worldToCameraTransform.appendingTranslation(-cameraSpaceLeftEyePosition)
                lodTransform2 = worldToCameraTransform.appendingTranslation(-cameraSpaceRightEyePosition)
                
                lodTransformInverse  = cameraToWorldTransform.prependingTranslation(cameraSpaceLeftEyePosition)
                lodTransformInverse2 = cameraToWorldTransform.prependingTranslation(cameraSpaceRightEyePosition)
            }
        } else {
            cullTransform = worldToScreenClipTransform
            
            if usingFlyingMode {
                lodTransform        = worldToFlyingPerspectiveTransform
                lodTransformInverse = flyingPerspectiveToWorldTransform
            } else {
                lodTransform        = worldToCameraTransform
                lodTransformInverse = cameraToWorldTransform
            }
        }
    }
    
    func render(object: ARObject) {
        if object.shouldPresent(cullTransform: cullTransform) {
            shapeContainers[object.shapeType.rawValue].appendAlias(of: object)
        }
    }
    
    /**
     Summary
     
     - Parameters:
        - desiredLOD: The target LOD. This may not be granted, but will be rounded to something close.
     */
    func render(object: ARObject, desiredLOD: Int) {
        if object.shouldPresent(cullTransform: cullTransform) {
            shapeContainers[object.shapeType.rawValue].appendAlias(of: object, desiredLOD: desiredLOD)
        }
    }
    
    func render(object: ARObject, desiredLOD: Int, userDistanceEstimate: Float) {
        if object.shouldPresent(cullTransform: cullTransform) {
            shapeContainers[object.shapeType.rawValue].appendAlias(of: object, desiredLOD: desiredLOD,
                                                                   userDistanceEstimate: userDistanceEstimate)
        }
    }
    
    
    
    @inlinable
    func render(objects: [ARObject]) {
        objects.forEach(render(object:))
    }
    
    @inlinable
    func render(objects: [ARObject], desiredLOD: Int) {
        objects.forEach{ render(object: $0, desiredLOD: desiredLOD) }
    }
    
    func render(objectGroup: ARObjectGroup, desiredLOD inputLOD: Int? = nil) {
        let boundsObject = ARObject(surrounding: objectGroup)
        if !boundsObject.shouldPresent(cullTransform: cullTransform) {
            return
        }
        
        let (desiredLOD, userDistanceEstimate) = inputLOD == nil
                                               ? getDistanceAndLOD(of: boundsObject)
                                               : (inputLOD!, getDistance(of: boundsObject))
        
        for object in objectGroup.objects {
            shapeContainers[object.shapeType.rawValue].appendAlias(of: object, desiredLOD: desiredLOD,
                                                                   userDistanceEstimate: userDistanceEstimate)
        }
    }
    
}

extension CentralRenderer: GeometryRenderer {
    
    func updateResources() {
        assert(shouldRenderToDisplay)
        
        let globalFragmentUniformPointer = globalFragmentUniformBuffer.contents().assumingMemoryBound(to: GlobalFragmentUniforms.self)
        globalFragmentUniformPointer[renderIndex] = GlobalFragmentUniforms(centralRenderer: self)
        
        for i in 0..<shapeContainers.count { shapeContainers[i].updateResources() }
    }
    
    enum GeometryType: CaseIterable {
        case object
    }
    
    func drawGeometry(type: GeometryType, renderEncoder: ARMetalRenderCommandEncoder) {
        assert(shouldRenderToDisplay)
        
        guard shapeContainers.contains(where: { $0.numAliases > 0 }) else {
            return
        }
        
        renderEncoder.pushOptDebugGroup("Render AR Objects")
        shapeContainers.forEach{ $0.drawGeometry(renderEncoder: renderEncoder) }
        renderEncoder.popOptDebugGroup()
    }
    
}
#endif

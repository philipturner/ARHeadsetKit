//
//  ARInterfaceElement.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/28/21.
//

import simd
    
public struct ARInterfaceElement {
    @usableFromInline internal var _object: ARObject
    @usableFromInline internal var _inverseScale: simd_float4
    
    public private(set) var radius: Float
    public private(set) var controlPoints: simd_float4x2
    public private(set) var normalTransform: simd_half3x3
    
    @inlinable public var surfaceColor: simd_half3 {
        get { _object.color }
        set { _object.color = newValue }
    }
    
    @inlinable public var surfaceShininess: Float16 {
        get { _object.shininess }
        set { _object.shininess = newValue }
    }
    
    public var surfaceOpacity: Float
    
    public var baseSurfaceColor: simd_half3
    public var highlightedSurfaceColor: simd_half3
    
    public var baseSurfaceOpacity: Float
    public var highlightedSurfaceOpacity: Float
    
    @usableFromInline internal var _isHighlighted = false
    @inlinable @inline(__always)
    public var isHighlighted: Bool {
        get { _isHighlighted }
        set {
            surfaceColor   = .init(newValue ? highlightedSurfaceColor   : baseSurfaceColor)
            surfaceOpacity =       newValue ? highlightedSurfaceOpacity : baseSurfaceOpacity
            
            _isHighlighted = newValue
        }
    }
    
    public var textColor: simd_half3
    public var textShininess: Float16
    public var textOpacity: Float16
    
    /// Hides the element from ray tracing and rendering.
    public var hidden = false
    
    public typealias CharacterGroup = InterfaceRenderer.CharacterGroup
    
    /**
     The text the element displays
     
     > Warning: If you change this without creating a new interface element, ensure that text does not overflow.
     */
    public var characterGroups: [CharacterGroup?]
    
    @inlinable
    public static func createOrientation(forwardDirection: simd_float3,
                                         orthogonalUpDirection: simd_float3) -> simd_quatf {
        let xAxis = cross(orthogonalUpDirection, forwardDirection)
        return simd_quatf(simd_float3x3(xAxis, orthogonalUpDirection, forwardDirection))
    }
    
    public init(position: simd_float3, forwardDirection: simd_float3, orthogonalUpDirection: simd_float3,
                width: Float, height: Float, depth: Float, radius: Float,
                
                highlightColor: simd_float3 = [0.2, 0.2, 0.9], highlightOpacity: Float = 1.0,
                surfaceColor:   simd_float3 = [0.1, 0.1, 0.8], surfaceShininess: Float = 32, surfaceOpacity: Float = 1.0,
                textColor:      simd_float3 = [0.9, 0.9, 0.9], textShininess:    Float = 32, textOpacity:    Float = 1.0,
                characterGroups: [CharacterGroup?])
    {
        let orientation = Self.createOrientation(forwardDirection: forwardDirection,
                                                 orthogonalUpDirection: orthogonalUpDirection)
        
        _object = ARObject(shapeType: .cube,
                           position: position,
                           orientation: orientation,
                           scale: simd_float3(width, height, depth),
                           
                           color: surfaceColor,
                           shininess: surfaceShininess)
        
        self.radius = max(min(radius, min(width, height) * 0.5), 0)
        _inverseScale = simd_precise_recip(simd_float4(width, height, depth, self.radius))
        
        controlPoints = Self.getControlPoints(width: width, height: height, radius: self.radius)
        normalTransform = simd_half3x3(simd_float3x3(orientation))
        
        baseSurfaceColor          = .init(surfaceColor)
        highlightedSurfaceColor   = .init(highlightColor)
        baseSurfaceOpacity        = surfaceOpacity
        highlightedSurfaceOpacity = highlightOpacity
        
        self.surfaceOpacity = surfaceOpacity
        
        self.textColor     = .init(textColor)
        self.textShininess = .init(textShininess)
        self.textOpacity   = .init(textOpacity)
        
        self.characterGroups = characterGroups
    }
    
    @inline(__always)
    private static func getControlPoints(width: Float, height: Float, radius: Float) -> simd_float4x2 {
        let outerX = width  * 0.5
        let outerY = height * 0.5
        
        let innerX = outerX - radius
        let innerY = outerY - radius
        
        return simd_float4x2(
            .init(innerX, outerX),
            .init(innerY, outerY),
            .init(innerX, outerX),
            .init(innerY, outerY)
        )
    }
    
    
    
    @inlinable public var position: simd_float3 { _object.position }
    @inlinable public var orientation: simd_quatf { _object.orientation }
    @inlinable public var scale: simd_float3 { _object.scale }
    
    public mutating func setProperties(position: simd_float3? = nil,
                                       orientation: simd_quatf? = nil,
                                       scale: simd_float3? = nil,
                                       radius: Float? = nil)
    {
        if let orientation = orientation {
            normalTransform = simd_half3x3(simd_float3x3(orientation))
        }
        
        if let radius = radius {
            self.radius = max(radius, 0)
        }
        
        if scale != nil || radius != nil {
            _inverseScale = simd_precise_recip(simd_float4(_object.scale, self.radius))
            
            controlPoints = Self.getControlPoints(width:  _object.scale.x,
                                                  height: _object.scale.y,
                                                  radius: self.radius)
        }
        
        _object.setProperties(position: position, orientation: orientation, scale: scale)
    }
    
    
    
    @inlinable @inline(__always)
    public func makeModelToWorldTransform() -> simd_float4x4 {
        var output = _object.modelToWorldTransform
        output[0] *= _inverseScale.x
        output[1] *= _inverseScale.y
        
        return output
    }
    
    func frontIsVisible(projectionTransform: simd_float4x4) -> Bool {
        let worldSpacePointA = simd_make_float3(_object.modelToWorldTransform * [-0.5, -0.5, 0.5, 1])
        let worldSpacePointB = simd_make_float3(_object.modelToWorldTransform * [ 0.5,  0.5, 0.5, 1])
        let worldSpacePointC = simd_make_float3(_object.modelToWorldTransform * [-0.5,  0.5, 0.5, 1])
        
        let pointA = projectionTransform * simd_float4(worldSpacePointA, 1)
        let pointB = projectionTransform * simd_float4(worldSpacePointB, 1)
        let pointC = projectionTransform * simd_float4(worldSpacePointC, 1)
        
        let reciprocalW = simd_precise_recip(simd_float3(pointA.w, pointB.w, pointC.w))
        let clipCoords = simd_float3x2(
            pointA.lowHalf * reciprocalW[0],
            pointB.lowHalf * reciprocalW[1],
            pointC.lowHalf * reciprocalW[2]
        )
        
        return simd_orient(clipCoords[1] - clipCoords[0], clipCoords[2] - clipCoords[0]) >= 0
    }
}

extension InterfaceRenderer {
    
    public func frontIsVisible(element: ARInterfaceElement) -> Bool {
        if renderer.cameraMeasurements.usingHeadsetMode {
            if element.frontIsVisible(projectionTransform: worldToLeftClipTransform) {
                return true
            }
            
            return element.frontIsVisible(projectionTransform: worldToRightClipTransform)
        } else {
            return element.frontIsVisible(projectionTransform: worldToScreenClipTransform)
        }
    }
    
    public func shouldPresent(element: ARInterfaceElement) -> Bool {
        guard !element.hidden else { return false }
        
        let cullTransform = centralRenderer.cullTransform
        return element._object.shouldPresent(cullTransform: cullTransform)
    }
    
}

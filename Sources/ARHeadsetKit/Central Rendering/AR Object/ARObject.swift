//
//  ARObject.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/18/21.
//

import simd

public struct ARObject {
    public var shapeType: ARShapeType
    
    public private(set) var modelToWorldTransform = simd_float4x4(1)
    public private(set) var worldToModelTransform = simd_float4x4(1)
    #if !os(macOS)
    public private(set) var normalTransform = matrix_identity_half3x3
    
    public var color: simd_half3
    public var shininess: Float16
    #endif
    public internal(set) var truncatedConeTopScale: Float
    public var allowsViewingInside: Bool
    
    @usableFromInline internal var _position: simd_float3
    @usableFromInline internal var _orientation: simd_quatf
    @usableFromInline internal var _scale: simd_float3
    
    @inlinable public var position: simd_float3 { _position }
    @inlinable public var orientation: simd_quatf { _orientation }
    @inlinable public var scale: simd_float3 { _scale }
    
    public init(shapeType: ARShapeType,
                position: simd_float3,
                orientation: simd_quatf = simd_quatf(angle: 0, axis: [0, 1, 0]),
                scale: simd_float3,
                
                color: simd_float3 = [0.333, 0.750, 1.000],
                shininess: Float = 32,
                truncatedConeTopScale: Float = .nan,
                allowsViewingInside: Bool = false)
    {
        self.shapeType = shapeType
        
        self._position = position
        self._orientation = orientation
        self._scale = scale
        
        #if !os(macOS)
        self.color = simd_half3(color)
        self.shininess = Float16(shininess)
        #endif
        self.truncatedConeTopScale = truncatedConeTopScale
        self.allowsViewingInside = allowsViewingInside
        
        if !truncatedConeTopScale.isNaN {
            assert(shapeType == .cylinder)
            
            if truncatedConeTopScale > 1 {
                _scale.x *= truncatedConeTopScale
                _scale.z *= truncatedConeTopScale
                
                self.truncatedConeTopScale = Float(simd_fast_recip(Double(truncatedConeTopScale)))
                
                _orientation *= simd_quatf(angle: degreesToRadians(180), axis: [1, 0, 0])
            }
        }
        
        _updateTransforms()
    }
    
    public init?(roundShapeType: ARShapeType,
                 bottomPosition: simd_float3,
                 topPosition: simd_float3,
                 diameter: Float,
                 
                 color: simd_float3 = [0.333, 0.750, 1.000],
                 shininess: Float = 32,
                 truncatedConeTopScale: Float = .nan,
                 allowsViewingInside: Bool = false)
    {
        assert(!roundShapeType.isPolyhedral, "Calling the bottomPosition - topPosition initializer on a non-round shape results in an undefined orientation!")
        
        guard bottomPosition != topPosition else {
            return nil
        }
        
        let position = (bottomPosition + topPosition) * 0.5
        
        let delta = topPosition - bottomPosition
        let deltaLength = length(delta)
        let orientationVector = delta / deltaLength
        let orientationQuaternion = simd_quatf(from: [0, 1, 0], to: orientationVector)
        
        self.init(shapeType: roundShapeType,
                  position: position,
                  orientation: orientationQuaternion,
                  scale: simd_float3(diameter, deltaLength, diameter),
                  
                  color: color,
                  shininess: shininess,
                  truncatedConeTopScale: truncatedConeTopScale,
                  allowsViewingInside: allowsViewingInside)
    }
    
    private init(shapeType: ARShapeType,
                 boundingBox: simd_float2x3,
                 scaleForLOD: simd_float3,
                 
                 color: simd_float3,
                 shininess: Float,
                 allowsViewingInside: Bool)
    {
        self.shapeType = shapeType
        
        let center = 0.5 * (boundingBox[0] + boundingBox[1])
        _position = center
        _scale = scaleForLOD
        _orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        
        let scale = boundingBox[1] - boundingBox[0]
        modelToWorldTransform = simd_float4x4(
            .init(scale.x, 0, 0, 0),
            .init(0, scale.y, 0, 0),
            .init(0, 0, scale.z, 0),
            .init(center,        1)
        )
        
        let inverseScale = simd_precise_recip(scale)
        worldToModelTransform = simd_float4x4(
            .init(inverseScale.x,  0,  0,  0),
            .init(0,  inverseScale.y,  0,  0),
            .init(0,  0,  inverseScale.z,  0),
            .init(-center * inverseScale,  1)
        )
        
        #if !os(macOS)
        self.color = simd_half3(color)
        self.shininess = Float16(shininess)
        #endif
        truncatedConeTopScale = .nan
        self.allowsViewingInside = allowsViewingInside
    }
    
    #if !os(macOS)
    internal init(surrounding objectGroup: ARObjectGroup) {
        let boundingBox = objectGroup.boundingBox
        
        self.init(shapeType: .sphere,
                  boundingBox: boundingBox,
                  scaleForLOD: objectGroup.scaleForLOD,
                  
                  color: .init(repeating: .nan),
                  shininess: .nan,
                  allowsViewingInside: false)
    }
    #endif
    
    public init(boundingBox: simd_float2x3,
                color: simd_float3 = [0.333, 0.750, 1.000],
                shininess: Float = 32,
                allowsViewingInside: Bool = false)
    {
        self.init(shapeType: .cube,
                  boundingBox: boundingBox,
                  scaleForLOD: boundingBox[1] - boundingBox[0],
                  
                  color: color,
                  shininess: shininess,
                  allowsViewingInside: allowsViewingInside)
    }
    
    @inlinable @inline(__always)
    internal mutating func setProperties(position: simd_float3? = nil,
                                         orientation: simd_quatf? = nil,
                                         scale: simd_float3? = nil)
    {
        guard position != nil || orientation != nil || scale != nil else {
            return
        }
        
        if let position = position { _position = position }
        if let orientation = orientation { _orientation = orientation }
        if let scale = scale { _scale = scale }
        
        _updateTransforms()
    }
    
    @usableFromInline
    internal mutating func _updateTransforms()
    {
        let rotationTransform = simd_float3x3(_orientation)
        let inverseScale = 1 / _scale
        #if !os(macOS)
        let normalScale = min(inverseScale, Float(sqrt(Float16.greatestFiniteMagnitude) * 0.99))
        normalTransform = simd_half3x3(
            rotationTransform[0] * normalScale[0],
            rotationTransform[1] * normalScale[1],
            rotationTransform[2] * normalScale[2]
        )
        #endif
        
        modelToWorldTransform = simd_float4x4(
            .init(_scale.x * rotationTransform[0], 0),
            .init(_scale.y * rotationTransform[1], 0),
            .init(_scale.z * rotationTransform[2], 0),
            .init(_position,                       1)
        )
        
        let rotationInverse = rotationTransform.transpose
        worldToModelTransform = simd_float4x4(
            .init(inverseScale *  rotationInverse[0],            0),
            .init(inverseScale *  rotationInverse[1],            0),
            .init(inverseScale *  rotationInverse[2],            0),
            .init(inverseScale * (rotationInverse * -_position), 1)
        )
    }
}



#if !os(macOS)
public extension CentralRenderer {
    
    typealias LODReturn = (lod: Int, distance: Float)
    
    /// This method is only exposed to mirror the `ARObjectUtilities` namespace in the Metal utilities.
    func getDistanceAndLOD(of object: ARObject) -> LODReturn {
        var distancesSquared: simd_float3
        
        if usingHeadsetMode {
            if object.cameraIsInside(cameraToWorldTransform) {
                return (1_000_001, 0)
            } else {
                distancesSquared = object.getDistancesSquared(worldToCameraTransform)
            }
        } else {
            if object.cameraIsInside(lodTransformInverse) ||
               object.cameraIsInside(lodTransformInverse2) {
                return (1_000_001, 0)
            } else {
                distancesSquared = min(object.getDistancesSquared(lodTransform),
                                       object.getDistancesSquared(lodTransform2))
            }
        }
        
        return object.getLODReturn(distancesSquared: distancesSquared)
    }
    
    /// This method is only exposed to mirror the `ARObjectUtilities` namespace in the Metal utilities.
    func getDistance(of object: ARObject) -> Float {
        if usingHeadsetMode {
            if object.cameraIsInside(cameraToWorldTransform) {
                return 0
            } else {
                return sqrt(object.getMinDistanceSquared(worldToCameraTransform))
            }
        } else {
            if object.cameraIsInside(lodTransformInverse) ||
               object.cameraIsInside(lodTransformInverse2) {
                return 0
            } else {
                return sqrt(min(object.getMinDistanceSquared(lodTransform),
                                object.getMinDistanceSquared(lodTransform2)))
            }
        }
    }
    
}

public extension ARObject {
    
    typealias LODReturn = CentralRenderer.LODReturn
    
    /// This method is only exposed to mirror the `ARObjectUtilities` namespace in the Metal utilities.
    func lod(lodTransform        worldToCameraTransform: simd_float4x4,
             lodTransformInverse cameraToWorldTransform: simd_float4x4) -> LODReturn {
        if cameraIsInside(cameraToWorldTransform) {
            return (1_000_001, 0)
        }
        
        let distancesSquared = getDistancesSquared(worldToCameraTransform)
        
        return getLODReturn(distancesSquared: distancesSquared)
    }
    
    /// This method is only exposed to mirror the `ARObjectUtilities` namespace in the Metal utilities.
    func lod(lodTransform1        worldToCameraTransform1: simd_float4x4,
             lodTransform2        worldToCameraTransform2: simd_float4x4,
             lodTransformInverse1 cameraToWorldTransform1: simd_float4x4,
             lodTransformInverse2 cameraToWorldTransform2: simd_float4x4) -> LODReturn {
        if cameraIsInside(cameraToWorldTransform1) ||
           cameraIsInside(cameraToWorldTransform2) {
            return (1_000_001, 0)
        }
        
        let distancesSquared = min(getDistancesSquared(worldToCameraTransform1),
                                   getDistancesSquared(worldToCameraTransform2))
        
        return getLODReturn(distancesSquared: distancesSquared)
    }
    
    fileprivate func getDistancesSquared(_ worldToCameraTransform: simd_float4x4) -> simd_float3 {
        let axisData = getAxisData(worldToCameraTransform)
        
        return [
            getSideDistanceSquared(index: 0, axisData: axisData),
            getSideDistanceSquared(index: 1, axisData: axisData),
            getSideDistanceSquared(index: 2, axisData: axisData)
        ]
    }
    
    fileprivate func getLODReturn(distancesSquared: simd_float3) -> LODReturn {
        var maxScales: simd_float3
        
        if shapeType == .sphere {
            maxScales = [
                max(scale[1], scale[2]),
                max(scale[0], scale[2]),
                max(scale[0], scale[1])
            ]
        } else {
            assert(shapeType == .cone || shapeType == .cylinder,
                   "Did not update LOD functions for the new round shape \(shapeType)!")
            
            maxScales = [
                scale[2],
                max(scale[0], scale[2]),
                scale[0]
            ]
        }
        
        let scaleMultipliers = cbrt(maxScales)
        
        let distanceReciprocals = simd_precise_rsqrt(distancesSquared)
        let desiredLOD = (scaleMultipliers * distanceReciprocals).max() * (40 * .pi)
        
        let distance = sqrt(distancesSquared.min())
        
        if desiredLOD > 1_000_000 || desiredLOD.isNaN {
            return (1_000_000, distance)
        } else {
            return (Int(desiredLOD), distance)
        }
    }
    
    fileprivate func cameraIsInside(_ cameraToWorldTransform: simd_float4x4) -> Bool {
        let pointInModelSpace = unsafeBitCast(worldToModelTransform, to: simd_float4x3.self) * cameraToWorldTransform.columns.3
        
        return all(abs(pointInModelSpace) .< 0.5)
    }
    
    fileprivate func getMinDistanceSquared(_ worldToCameraTransform: simd_float4x4) -> Float {
        let axisData = getAxisData(worldToCameraTransform)
        let axisDistancesSquared = axisData.distancesSquared
        
        var minIndex = axisDistancesSquared       [0] < axisDistancesSquared[1] ?        0 : 1
        minIndex     = axisDistancesSquared[minIndex] < axisDistancesSquared[2] ? minIndex : 2
        
        return getSideDistanceSquared(index: minIndex, axisData: axisData)
    }
    
}

extension ARObject {
    
    fileprivate typealias AxisData = (deltas:           simd_float3x3,
                                      normalizedDeltas: simd_float3x3,
                                      positions:        simd_float3x3,
                                      distancesSquared: simd_float3)
    
    fileprivate func getAxisData(_ worldToCameraTransform: simd_float4x4) -> AxisData {
        let modelToCameraTransform = unsafeBitCast(worldToCameraTransform * modelToWorldTransform, to: simd_float4x3.self)
        
        let centerPosition = modelToCameraTransform.columns.3
        
        var deltas = simd_float3x3(
            0.5 * simd_make_float3(modelToCameraTransform.columns.0),
            0.5 * simd_make_float3(modelToCameraTransform.columns.1),
            0.5 * simd_make_float3(modelToCameraTransform.columns.2)
        )
        
        var positions = simd_float3x3(
            deltas[0] + centerPosition,
            deltas[1] + centerPosition,
            deltas[2] + centerPosition
        )
        
        let centerDistanceSquared = length_squared(centerPosition)
        
        var distancesSquared = simd_float3(
            length_squared(positions[0]),
            length_squared(positions[1]),
            length_squared(positions[2])
        )
        
        for i in 0..<3 {
            if distancesSquared[i] > centerDistanceSquared {
                let newPosition = centerPosition - deltas[i]
                let newDistanceSquared = length_squared(newPosition)
                
                if newDistanceSquared < distancesSquared[i] {
                    deltas[i] = -deltas[i]
                    positions[i] = newPosition
                    distancesSquared[i] = newDistanceSquared
                }
            }
        }
        
        let deltas_lengthSquared = dotAdd(deltas[0], deltas[0],
                                          deltas[1], deltas[1],
                                          deltas[2], deltas[2])
        
        let deltas_inverseLength = simd_precise_rsqrt(deltas_lengthSquared)
        
        let normalizedDeltas = simd_float3x3(
            deltas[0] * deltas_inverseLength[0],
            deltas[1] * deltas_inverseLength[1],
            deltas[2] * deltas_inverseLength[2]
        )
        
        return (deltas, normalizedDeltas, positions, distancesSquared)
    }
    
    fileprivate func getSideDistanceSquared(index: Int, axisData: AxisData) -> Float {
        let planeNormal = axisData.normalizedDeltas[index]
        let planeOrigin = axisData.positions       [index]
        
        let projectedPoint = fma(dot(planeOrigin, planeNormal), planeNormal, -planeOrigin)
        
        var altIndex1, altIndex2: Int
        
        if      index == 0 { (altIndex1, altIndex2) = (1, 2) }
        else if index == 1 { (altIndex1, altIndex2) = (0, 2) }
        else               { (altIndex1, altIndex2) = (0, 1) }
        
        @inline(__always)
        func getClosestPoint() -> simd_float3 {
            let normalizedDelta1 = axisData.normalizedDeltas[altIndex1]
            let normalizedDelta2 = axisData.normalizedDeltas[altIndex2]
            
            let component1 = dot(projectedPoint, normalizedDelta1)
            let component2 = dot(projectedPoint, normalizedDelta2)
            
            let delta1 = axisData.deltas[altIndex1]
            let delta2 = axisData.deltas[altIndex2]
            
            let deltaLengthsSquared = dotAdd(delta1, delta1,
                                             delta2, delta2)
            
            let componentsSquared = simd_float2(component1 * component1,
                                                component2 * component2)
            
            if componentsSquared[0] > deltaLengthsSquared[0] {
                if componentsSquared[1] > deltaLengthsSquared[1] {
                    return delta1 + delta2
                } else {
                    return fma(normalizedDelta2, component2, delta1)
                }
            } else {
                if componentsSquared[1] > deltaLengthsSquared[1] {
                    return fma(normalizedDelta1, component1, delta2)
                } else {
                    return projectedPoint
                }
            }
        }
        
        let closestPoint = getClosestPoint() + planeOrigin
        
        return length_squared(closestPoint)
    }
    
}
#endif

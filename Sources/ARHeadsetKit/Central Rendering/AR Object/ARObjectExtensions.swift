//
//  ARObjectExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/28/21.
//

import simd



/**
  ARObjectGroup accelerates culling and finding LOD of ARObjects
  by treating of a group of several close objects as one larger object.
 
  If one object is visible, all will be rendered. In addition, all
  objects are rendered at the maximum LOD of any object in the group.
 */
public struct ARObjectGroup {
    public let objects: [ARObject]
    
    @inlinable
    public var boundingBox: simd_float2x3 {
        let worldLimits = simd_float2x3(.init(repeating:  .greatestFiniteMagnitude),
                                        .init(repeating: -.greatestFiniteMagnitude))
        
        return objects.reduce(into: worldLimits) {
            let currentBox = $1.boundingBox
            
            $0.columns.0 = min($0.columns.0, currentBox.columns.0)
            $0.columns.1 = max($0.columns.1, currentBox.columns.1)
        }
    }
    
    var scaleForLOD: simd_float3 {
        let maxScale = simd_float3(repeating: .greatestFiniteMagnitude)
        
        return objects.reduce(into: maxScale){ $0 = max($0, $1.scale) }
    }
}

extension ARObject {
    
    #if !os(macOS)
    struct Alias {
        var modelToWorldTransform: simd_float4x4
        var normalTransform: simd_half3x3
        
        var color: simd_packed_half3
        var shininess: Float16
        var truncatedConeTopScale: Float
        var truncatedConeNormalMultipliers: simd_half2
        
        var allowsViewingInside: Bool
        
        init(object: ARObject) {
            modelToWorldTransform = object.modelToWorldTransform
            normalTransform = object.normalTransform
            
            color = simd_packed_half3(object.color)
            shininess = object.shininess
            truncatedConeTopScale = object.truncatedConeTopScale
            
            if truncatedConeTopScale.isNaN {
                truncatedConeNormalMultipliers = [.nan, .nan]
            } else {
                let lengthMultiplierSquared = simd_fast_recip(length_squared(.init(1 - truncatedConeTopScale, 1)))
                let output = simd_float2(lengthMultiplierSquared, 1 - lengthMultiplierSquared)
                truncatedConeNormalMultipliers = simd_half2(sqrt(output))
            }
            
            allowsViewingInside = object.allowsViewingInside
        }
    }
    
    var alias: Alias { Alias(object: self) }
    #endif
    
    struct ProjectedCorners {
        private var lowerCorners: simd_float4x4
        private var upperCorners: simd_float4x4
        
        init(lowerCorners: simd_float4x4, upperCorners: simd_float4x4) {
            func makeCorners(_ input: simd_float4x4) -> simd_float4x4 {
                @inline(__always)
                func createDimensionVector(_ input: simd_float4x4, index: Int) -> simd_float4 {
                    return simd_float4(
                        input[0][index],
                        input[1][index],
                        input[2][index],
                        input[3][index]
                    )
                }
                
                return simd_float4x4(
                    createDimensionVector(input, index: 0),
                    createDimensionVector(input, index: 1),
                    createDimensionVector(input, index: 2),
                    createDimensionVector(input, index: 3)
                )
            }
            
            self.lowerCorners = makeCorners(lowerCorners)
            self.upperCorners = makeCorners(upperCorners)
        }
        
        @inline(__always)
        static func createLowerCorners(boundingBox b: simd_float2x3) -> simd_float4x4 {
            simd_float4x4(
                .init(b[0][0], b[0][1], b[0][2], 1),
                .init(b[0][0], b[0][1], b[1][2], 1),
                .init(b[0][0], b[1][1], b[0][2], 1),
                .init(b[0][0], b[1][1], b[1][2], 1)
            )
        }
        
        @inline(__always)
        static func createUpperCorners(boundingBox b: simd_float2x3) -> simd_float4x4 {
            simd_float4x4(
                .init(b[1][0], b[0][1], b[0][2], 1),
                .init(b[1][0], b[0][1], b[1][2], 1),
                .init(b[1][0], b[1][1], b[0][2], 1),
                .init(b[1][0], b[1][1], b[1][2], 1)
            )
        }
        
        var boundingBox: simd_float2x3 {
            let minX = min(lowerCorners[0], upperCorners[0]).min()
            let minY = min(lowerCorners[1], upperCorners[1]).min()
            let minZ = min(lowerCorners[2], upperCorners[2]).min()
            
            let maxX = max(lowerCorners[0], upperCorners[0]).max()
            let maxY = max(lowerCorners[1], upperCorners[1]).max()
            let maxZ = max(lowerCorners[2], upperCorners[2]).max()
            
            return simd_float2x3(
                .init(minX, minY, minZ),
                .init(maxX, maxY, maxZ)
            )
        }
        
        var areVisible: Bool {
            if all(lowerCorners[0] .>  lowerCorners[3] .& upperCorners[0] .>  upperCorners[3])
            || all(lowerCorners[0] .< -lowerCorners[3] .& upperCorners[0] .< -upperCorners[3]) { return false }
            
            if all(lowerCorners[1] .>  lowerCorners[3] .& upperCorners[1] .>  upperCorners[3])
            || all(lowerCorners[1] .< -lowerCorners[3] .& upperCorners[1] .< -upperCorners[3]) { return false }
            
            if all(lowerCorners[2] .>= lowerCorners[3] .& upperCorners[2] .>= upperCorners[3])
            || all(lowerCorners[2] .<  0               .& upperCorners[2] .<  0) { return false }
            
            return true
        }
    }
    
    static func projectedPointsAreVisible(_ points: [simd_float4]) -> Bool {
        if points.allSatisfy({ $0.x >  $0.w }) { return false }
        if points.allSatisfy({ $0.x < -$0.w }) { return false }

        if points.allSatisfy({ $0.y >  $0.w }) { return false }
        if points.allSatisfy({ $0.y < -$0.w }) { return false }

        if points.allSatisfy({ $0.z >= $0.w }) { return false }
        if points.allSatisfy({ $0.z <   0   }) { return false }
        
        return true
    }
    
    @inline(__always)
    private static func makeCorners(x: Float, transform: simd_float4x4) -> simd_float4x4 {
        simd_float4x4(
            transform * simd_float4(x, -0.5, -0.5, 1),
            transform * simd_float4(x, -0.5,  0.5, 1),
            transform * simd_float4(x,  0.5, -0.5, 1),
            transform * simd_float4(x,  0.5,  0.5, 1)
        )
    }
    
    static func makeLowerCorners(_ transform: simd_float4x4) -> simd_float4x4 {
        makeCorners(x: -0.5, transform: transform)
    }
    
    static func makeUpperCorners(_ transform: simd_float4x4) -> simd_float4x4 {
        makeCorners(x:  0.5, transform: transform)
    }
    
    /// This method is only exposed to mirror the `ARObjectUtilities` namespace in the Metal utilities.
    public func shouldPresent(cullTransform worldToClipTransform: simd_float4x4) -> Bool {
        let modelToClipTransform = worldToClipTransform * modelToWorldTransform
        
        let projectedCorners = ProjectedCorners(lowerCorners: Self.makeLowerCorners(modelToClipTransform),
                                                upperCorners: Self.makeUpperCorners(modelToClipTransform))
        return projectedCorners.areVisible
    }
    
    /// Use this with ``RayTracing/Ray/transformedIntoBoundingBox(_:)`` on a ``RayTracing/Ray``.
    public var boundingBox: simd_float2x3 {
        let projectedCorners = ProjectedCorners(lowerCorners: Self.makeLowerCorners(modelToWorldTransform),
                                                upperCorners: Self.makeUpperCorners(modelToWorldTransform))
        
        return projectedCorners.boundingBox
    }
    
}

extension ARObject: RayTraceable {
    
    public func trace(ray worldSpaceRay: RayTracing.Ray) -> Float? {
        let ray = RayTracing.Ray(origin:    simd_make_float3(worldToModelTransform * simd_float4(worldSpaceRay.origin, 1)),
                                 direction: simd_make_float3(worldToModelTransform * simd_float4(worldSpaceRay.direction, 0)))
        
        guard ray.passesInitialBoundingBoxTest() else {
            return nil
        }
        
        if shapeType.isPolyhedral {
            return ray.getProgress(polyhedralShape: shapeType)
        } else {
            let retrievedTopScale = truncatedConeTopScale
            
            if !retrievedTopScale.isNaN {
                return ray.getCentralTruncatedConeProgress(topScale: retrievedTopScale)
            } else {
                return ray.getProgress(roundShape: shapeType)
            }
        }
    }
    
}

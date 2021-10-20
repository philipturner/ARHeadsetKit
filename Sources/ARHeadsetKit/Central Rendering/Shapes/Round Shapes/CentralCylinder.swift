//
//  CentralCylinder.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/17/21.
//

import Metal
import simd

#if !os(macOS)
struct CentralCylinder: CentralRoundShape {
    static var shapeType: CentralShapeType = .cylinder
    
    var numIndices: Int
    var normalOffset: Int
    var indexOffset: Int
    
    init(centralRenderer: CentralRenderer, numSegments: UInt16,
         vertices: inout [CentralVertex], indices: inout [UInt16])
    {
        let circleVertices = centralRenderer.circle(numSegments: numSegments)
        
        var currentVertices = [CentralVertex(position: [0, 0.5, 0], normal: [0, 1, 0])]
        var currentIndexOffset: UInt16 = 1
        var currentIndices = Self.makeRoundTipIndices(circleStart: currentIndexOffset, numSegments: numSegments, upward: true)
        
        currentVertices += circleVertices.map {
            CentralVertex(position: [$0.x, 0.5, $0.y], normal: [0, 1, 0])
        }
        
        currentIndexOffset += numSegments
        
        currentVertices += circleVertices.map {
            let position = simd_float3($0.x, 0.5, $0.y)
            var normal = position + position
            normal.y = 0
            
            return CentralVertex(position: position, normal: normal)
        }
        
        currentIndices += Self.makeRoundSectionIndices(upperStart: currentIndexOffset, numSegments: numSegments)
        currentIndexOffset += numSegments
        
        currentVertices += circleVertices.map {
            let position = simd_float3($0.x, -0.5, $0.y)
            var normal = position + position
            normal.y = 0
            
            return CentralVertex(position: position, normal: normal)
        }
        
        currentIndexOffset += numSegments
        
        currentVertices += circleVertices.map {
            CentralVertex(position: [$0.x, -0.5, $0.y], normal: [0, -1, 0])
        }
        
        currentIndices += Self.makeRoundTipIndices(circleStart: currentIndexOffset, numSegments: numSegments, upward: false)
        
        currentVertices.append(CentralVertex(position: [0, -0.5, 0], normal: [0, -1, 0]))
        
        numIndices   = currentIndices.count
        normalOffset = vertices.count * MemoryLayout<simd_half3>.stride
        indexOffset  = indices.count * MemoryLayout<UInt16>.stride
        
        vertices += currentVertices
        indices  += currentIndices
    }
}
#endif

public extension RayTracing.Ray {
    
    /// Intersects a cylinder confined to model space.
    @inlinable
    func getCentralCylinderProgress() -> Float? {
        var possibleBaseProgress: Float?
        
        if direction.y != 0 {
            let possibleProgress = getBoundingCoordinatePlaneProgress(index: 1)
            
            let projection3D = project(progress: possibleProgress)
            let projection2D = simd_float2(projection3D.x, projection3D.z)
            
            if length_squared(projection2D) < 0.25 {
                possibleBaseProgress = possibleProgress
            }
        } else {
            assert(abs(origin.y) < 0.5)
        }
        
        let direction2D = simd_float2(direction.x, direction.z)
        let origin2D    = simd_float2(origin.x,    origin.z)
        
        var coefficients = dotAdd(direction2D, direction2D,
                                  direction2D, origin2D,
                                  origin2D,    origin2D, rhs2: -0.25)
        
        coefficients[2] *= coefficients[0]
        
        guard var middleProgress = finishRoundShapeProgress(coefficients[1], coefficients[2]) else {
            return possibleBaseProgress
        }
        
        middleProgress /= coefficients[0]
        
        if abs(fma(direction.y, middleProgress, origin.y)) > 0.5 {
            return possibleBaseProgress
        }
        
        if let baseProgress = possibleBaseProgress {
            return min(baseProgress, middleProgress)
        } else {
            return middleProgress
        }
    }
    
    /**
     Intersects a truncated cone confined to model space.
     
     - Parameters:
        - topScale: Must be between 0 and 1.
     */
    @inlinable
    func getTruncatedConeProgress(topScale: Float) -> Float? {
        assert(topScale <= 1, "Truncated cone top scale must be <= 1")
        
        guard topScale != 1 else {
            return getCylinderProgress()
        }
        
        var possibleEndProgress: Float?
        
        if origin.y >= 0.5 {
            if let topProgress = getTruncatedConeTopProgress(topScale: topScale) {
                return topProgress
            }

        } else if origin.y <= -0.5 {
            if let baseProgress = getConeBaseProgress() {
                return baseProgress
            }
        } else {
            possibleEndProgress = getCentralTruncatedConeTopProgress(topScale: topScale)
            
            if let baseProgress = getCentralConeBaseProgress() {
                if let topProgress = possibleEndProgress {
                    possibleEndProgress = min(baseProgress, topProgress)
                } else {
                    possibleEndProgress = baseProgress
                }
            }
        }
        
        let scaleY = 1 - topScale
        
        let adjustedCoords = fma(simd_float3(1, origin.y + 0.5, direction.y),
                                 scaleY,
                                 simd_float3(-0.5, -0.5, 0))
        
        var adjustedTopY:       Float { adjustedCoords[0] }
        var adjustedOriginY:    Float { adjustedCoords[1] }
        var adjustedDirectionY: Float { adjustedCoords[2] }
        
        let adjustedRay = Self(origin:    .init(origin.x,    adjustedOriginY,    origin.z),
                               direction: .init(direction.x, adjustedDirectionY, direction.z))
        
        if let middleProgress = adjustedRay.getCentralConeMiddleProgress(topY: adjustedTopY) {
            if let endProgress = possibleEndProgress {
                return min(endProgress, middleProgress)
            } else {
                return middleProgress
            }
        } else {
            return possibleEndProgress
        }
    }
    
    /**
     Intersects the top of a truncated cone confined to model space.
     
     - Parameters:
        - topScale: Must be between 0 and 1.
     */
    @inlinable
    func getTruncatedConeTopProgress(topScale: Float) -> Float? {
        let origin_to_base_distance = 0.5 - origin.y
        let baseProgress = origin_to_base_distance / direction.y
        guard baseProgress > 0 else { return nil }
        
        let projection3D = project(progress: baseProgress)
        let projection2D = simd_float2(projection3D.x, projection3D.z)
        
        if length_squared(projection2D) <= topScale * topScale * 0.25 {
            return baseProgress
        } else {
            return nil
        }
    }
    
}

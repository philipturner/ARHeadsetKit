//
//  CentralCone.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/17/21.
//

import Metal
import simd

#if !os(macOS)
struct CentralCone: CentralRoundShape {
    static let shapeType: ARShapeType = .cone
    
    var numIndices: Int
    var normalOffset: Int
    var indexOffset: Int
    
    init(centralRenderer: CentralRenderer, numSegments: UInt16,
         vertices: inout [CentralVertex], indices: inout [UInt16])
    {
        let circleVertices = centralRenderer.circle(numSegments: numSegments)
        
        var currentVertices = [CentralVertex]()
        var currentIndices = Self.makePointedTipIndices(upperStart: 0, numSegments: numSegments, upward: true)
        
        let i_end = circleVertices.count - 1
        var lastDirection = circleVertices[0] + circleVertices[i_end]
        var directionMultiplier = rsqrt(length_squared(lastDirection))
        
        directionMultiplier *= sqrt(0.8)
        lastDirection *= directionMultiplier
        
        var cachedCircleVertex = circleVertices[0]
        
        for i in 1...i_end {
            let currentCircleVertex = circleVertices[i]
            var direction = cachedCircleVertex + currentCircleVertex
            
            direction *= directionMultiplier
            let normal = simd_float3(direction.x, sqrt(0.2), direction.y)
            
            cachedCircleVertex = currentCircleVertex
            currentVertices.append(CentralVertex(position: [0, 0.5, 0], normal: normal))
        }
        
        let lastNormal = simd_float3(lastDirection.x, sqrt(0.2), lastDirection.y)
        currentVertices.append(CentralVertex(position: [0, 0.5, 0], normal: lastNormal))
        
        currentVertices += circleVertices.map {
            let direction = $0 * sqrt(0.8) * 2
            let normal = simd_float3(direction.x, sqrt(0.2), direction.y)
            
            return CentralVertex(position: [$0.x, -0.5, $0.y], normal: normal)
        }
        
        currentIndices += Self.makeRoundTipIndices(circleStart: numSegments + numSegments, numSegments: numSegments, upward: false)
        
        currentVertices += circleVertices.map {
            CentralVertex(position: [$0.x, -0.5, $0.y], normal: [0, -1, 0])
        }
        
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
    
    /// Intersects a cone confined to model space.
    @inlinable
    func getConeProgress() -> Float? {
        let possibleBaseProgress = getConeBaseProgress()
        
        if origin.y <= -0.5, possibleBaseProgress != nil {
            return possibleBaseProgress
        }
        
        if let middleProgress = getConeMiddleProgress() {
            if let baseProgress = possibleBaseProgress {
                return min(baseProgress, middleProgress)
            } else {
                return middleProgress
            }
        } else {
            return possibleBaseProgress
        }
    }
    
    /// Intersects a cone confined to model space, except that its tip may extend above `y = 0.5`.
    @inlinable
    func getConeMiddleProgress(topY: Float = 0.5) -> Float? {
        let theta = atan2(Float(1), 2)
        let angle_multiplier = cos(theta) * cos(theta)
        
        let CO = origin - simd_float3(0, 0.5, 0)
        
        var coefficients = dotAdd(direction, direction,
                                  direction, CO,
                                  CO,        CO) * -angle_multiplier
        
        coefficients = fma(simd_float3(direction.y, direction.y, CO.y),
                           simd_float3(direction.y, CO.y,        CO.y), coefficients)
        
        var a:      Float { coefficients[0] }
        var b_half: Float { coefficients[1] }
        var c:      Float { coefficients[2] }
        
        let discriminant_4th = fma(b_half, b_half, -a * c)
        guard discriminant_4th >= 0 else { return nil }
        
        let discriminant_sqrt_half = sqrt(discriminant_4th)
        
        var solutions = simd_float2(
            discriminant_sqrt_half,
           -discriminant_sqrt_half
        ) - b_half
        
        solutions.replace(with: [.nan, .nan], where: sign(solutions) .!= sign(a))
        solutions /= a
        
        let P_y = fma(direction.y, solutions, origin.y)
        
        solutions.replace(with: [.nan, .nan], where: P_y .> topY .| P_y .< -0.5)
        
        let possibleTipProgress = solutions.min()
        return possibleTipProgress.isNaN ? nil : possibleTipProgress
    }
    
    /// Intersects the base of a cone confined to model space.
    @inlinable
    func getConeBaseProgress() -> Float? {
        let origin_to_base_distance = -0.5 - origin.y
        let baseProgress = origin_to_base_distance / direction.y
        guard baseProgress > 0 else { return nil }
        
        let projection3D = project(progress: baseProgress)
        let projection2D = simd_float2(projection3D.x, projection3D.z)
        
        if length_squared(projection2D) < 0.25 {
            return baseProgress
        } else {
            return nil
        }
    }
    
}

//
//  CentralOctahedron.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/16/21.
//

import Metal
import simd

#if !os(macOS)
struct CentralOctahedron: CentralPolyhedralShape {
    static var shapeType: CentralShapeType = .octahedron
    
    var numIndices: Int
    var normalOffset: Int
    var indexOffset: Int
    
    init(centralRenderer: CentralRenderer, numSegments _: UInt16,
         vertices: inout [CentralVertex], indices: inout [UInt16])
    {
        let positions: [simd_float3] = [
            [ 0,   0, -0.5],
            [ 0.5, 0,  0  ],
            [ 0,   0,  0.5],
            [-0.5, 0,  0  ],
        ]
        
        let normals: [simd_float3] = [
            [ 1, 1, -1] / sqrt(3),
            [ 1, 1,  1] / sqrt(3),
            [-1, 1,  1] / sqrt(3),
            [-1, 1, -1] / sqrt(3),
        ]
        
        let currentIndices = Array(UInt16(0)..<24)
        
        var currentVertices = (0..<4).flatMap { sideID -> [CentralVertex] in
            let leftVertex  = positions[(sideID + 1) & 3]
            let rightVertex = positions[ sideID ]
            let topVertex   = simd_float3(0, 0.5, 0)
            
            let normal = normals[sideID]
            
            return [leftVertex, rightVertex, topVertex].map {
                CentralVertex(position: $0, normal: normal)
            }
        }
        
        currentVertices += (0..<4).flatMap { sideID -> [CentralVertex] in
            let rightVertex  = positions[ sideID ]
            let leftVertex   = positions[(sideID + 1) & 3]
            let bottomVertex = simd_float3(0, -0.5, 0)
            
            var normal = normals[sideID]
            normal.y = -normal.y
            
            return [rightVertex, leftVertex, bottomVertex].map {
                CentralVertex(position: $0, normal: normal)
            }
        }
        
        numIndices   = currentIndices.count
        normalOffset = vertices.count * MemoryLayout<simd_half3>.stride
        indexOffset  = indices.count  * MemoryLayout<UInt16>.stride
        
        vertices += currentVertices
        indices  += currentIndices
    }
}
#endif

public extension RayTracing.Ray {
    
    /// Intersects an octahedron confined to model space.
    @inlinable
    func getOctahedronProgress() -> Float? {
        func getProgressCommon(intersections: inout simd_float4, minY: Float, maxY: Float) -> Float? {
            let projectionsY = fma(direction.y, intersections, origin.y)
            var invalidMarks = (projectionsY .> maxY) .| (projectionsY .< minY)
            
            let projectionsX = fma(direction.x, intersections, origin.x)
            invalidMarks .|= 0 .< simd_float4(
                lowHalf: -projectionsX.lowHalf,
                highHalf: projectionsX.highHalf
            )
            
            let projectionsZ = fma(direction.z, intersections, origin.z)
            invalidMarks .|= 0 .< simd_float4(
                -projectionsZ[0],
                 projectionsZ[1],
                 projectionsZ[2],
                -projectionsZ[3]
            )
            
            invalidMarks .|= intersections .< 0
            
            intersections.replace(with: .init(repeating: .nan), where: invalidMarks)
            
            let possibleTipProgress = intersections.min()
            return possibleTipProgress.isNaN ? nil : possibleTipProgress
        }
        
        let sqrtThird = sqrt(Float(1) / 3)
        
        func getUpperProgress() -> Float? {
            func getIntersection(planeNormal: simd_float3) -> Float {
                let testPlane = RayTracing.Plane(simd_float3(0, 0.5, 0), planeNormal)
                return RayTracing.getProgress(self, onto: testPlane)
            }
            
            var intersections = simd_float4(
                getIntersection(planeNormal: .init( sqrtThird, sqrtThird,  sqrtThird)),
                getIntersection(planeNormal: .init( sqrtThird, sqrtThird, -sqrtThird)),
                getIntersection(planeNormal: .init(-sqrtThird, sqrtThird, -sqrtThird)),
                getIntersection(planeNormal: .init(-sqrtThird, sqrtThird,  sqrtThird))
            )
            
            return getProgressCommon(intersections: &intersections, minY: 0, maxY: 0.5)
        }
        
        func getLowerProgress() -> Float? {
            func getIntersection(planeNormal: simd_float3) -> Float {
                let testPlane = RayTracing.Plane(simd_float3(0, -0.5, 0), planeNormal)
                return RayTracing.getProgress(self, onto: testPlane)
            }
            
            var intersections = simd_float4(
                getIntersection(planeNormal: .init( sqrtThird, -sqrtThird,  sqrtThird)),
                getIntersection(planeNormal: .init( sqrtThird, -sqrtThird, -sqrtThird)),
                getIntersection(planeNormal: .init(-sqrtThird, -sqrtThird, -sqrtThird)),
                getIntersection(planeNormal: .init(-sqrtThird, -sqrtThird,  sqrtThird))
            )
            
            return getProgressCommon(intersections: &intersections, minY: -0.5, maxY: 0)
        }
        
        if origin.y >= 0 {
            if direction.y >= 0 {
                assert(origin.y < 0.5)
                return getUpperProgress()
            } else {
                if let upperProgress = getUpperProgress() {
                    return upperProgress
                } else {
                    return getLowerProgress()
                }
            }
        } else {
            if direction.y <= 0 {
                assert(origin.y > 0.5)
                return getLowerProgress()
            } else {
                if let lowerProgress = getLowerProgress() {
                    return lowerProgress
                } else {
                    return getUpperProgress()
                }
            }
        }
    }
    
}

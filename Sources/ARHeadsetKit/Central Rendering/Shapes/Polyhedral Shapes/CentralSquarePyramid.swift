//
//  CentralSquarePyramid.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/16/21.
//

import Metal
import simd

#if !os(macOS)
struct CentralSquarePyramid: CentralPolyhedralShape {
    static var shapeType: CentralShapeType = .squarePyramid
    
    var numIndices: Int
    var normalOffset: Int
    var indexOffset: Int
    
    init(centralRenderer: CentralRenderer, numSegments _: UInt16,
         vertices: inout [CentralVertex], indices: inout [UInt16])
    {
        let positions: [simd_float3] = [
            [ 0.5, -0.5, -0.5],
            [ 0.5, -0.5,  0.5],
            [-0.5, -0.5,  0.5],
            [-0.5, -0.5, -0.5],
        ]
        
        let normals: [simd_float3] = [
            [ sqrt(0.5), sqrt(0.5),       0   ],
            [      0,    sqrt(0.5),  sqrt(0.5)],
            [-sqrt(0.5), sqrt(0.5),       0   ],
            [      0,    sqrt(0.5), -sqrt(0.5)]
        ]
        
        var currentIndices: [UInt16] = [0, 1, 2, 0, 2, 3]
        
        var currentVertices = positions.map {
            CentralVertex(position: $0, normal: [0, -0.5, 0])
        }
        
        currentIndices += 4..<16
        
        currentVertices += (0..<4).flatMap { sideID -> [CentralVertex] in
            let leftVertex  = positions[(sideID + 1) & 3]
            let rightVertex = positions[ sideID ]
            let topVertex   = simd_float3(0, 0.5, 0)
            
            let normal = normals[sideID]
            
            return [leftVertex, rightVertex, topVertex].map {
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
    
    /// Intersects a square pyramid confined to model space.
    @inlinable
    func getCentralSquarePyramidProgress() -> Float? {
        if origin.y <= -0.5 {
            assert(direction.y > 0)
            
            let origin_to_base_distance = -0.5 - origin.y
            let baseProgress = origin_to_base_distance / direction.y
            let projection3D = project(progress: baseProgress)
            let projection2D = simd_float2(projection3D.x, projection3D.z)
            
            if all(abs(projection2D) .<= 0.5) {
                return baseProgress
            }
        }
        
        func getIntersection(planeNormal: simd_float3) -> Float {
            let testPlane = RayTracing.Plane(simd_float3(0, 0.5, 0), planeNormal)
            return RayTracing.getProgress(self, onto: testPlane)
        }
        
        var intersections = simd_float4(
            getIntersection(planeNormal: .init( sqrt(0.8), sqrt(0.2),       0   )),
            getIntersection(planeNormal: .init(      0,    sqrt(0.2), -sqrt(0.8))),
            getIntersection(planeNormal: .init(-sqrt(0.8), sqrt(0.2),       0   )),
            getIntersection(planeNormal: .init(      0,    sqrt(0.2),  sqrt(0.8)))
        )
        
        let projectionsY = fma(direction.y, intersections, origin.y)
        var invalidMarks = (projectionsY .> 0.5) .| (projectionsY .< -0.5)
        
        let projectionsX = fma(direction.x, intersections, origin.x)
        let projectionsZ = fma(direction.z, intersections, origin.z)
        
        let absVector = abs(simd_float4(
            projectionsZ[0],
            projectionsX[1],
            projectionsZ[2],
            projectionsX[3]
        ))
        
        invalidMarks .|= absVector .> simd_float4(
             projectionsX[0],
            -projectionsZ[1],
            -projectionsX[2],
             projectionsZ[3]
        )
        
        invalidMarks .|= intersections .< 0

        intersections.replace(with: .init(repeating: .nan), where: invalidMarks)
        
        let possibleTipProgress = intersections.min()
        return possibleTipProgress.isNaN ? nil : possibleTipProgress
    }
    
}

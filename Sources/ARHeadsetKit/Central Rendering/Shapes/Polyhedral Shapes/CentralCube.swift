//
//  CentralCube.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/17/21.
//

import Metal
import simd

#if !os(macOS)
struct CentralCube: CentralPolyhedralShape {
    static let shapeType: ARShapeType = .cube
    
    var numIndices: Int
    var normalOffset: Int
    var indexOffset: Int
    
    init(centralRenderer: CentralRenderer, numSegments _: UInt16,
         vertices: inout [CentralVertex], indices: inout [UInt16])
    {
        let normalVectors: [simd_float3] = [
            [-0.5, 0,   0  ],
            [ 0,  -0.5, 0  ],
            [ 0,   0,  -0.5],
            [ 0.5, 0,   0  ],
            [ 0,   0.5, 0  ],
            [ 0,   0,   0.5]
        ]
        
        let horizontalVectors: [simd_float3] = [
            [ 0,   0,  0.5],
            [ 0.5, 0,  0  ],
            [-0.5, 0,  0  ],
            [ 0,   0, -0.5],
            [ 0.5, 0,  0  ],
            [ 0.5, 0,  0  ],
        ]
        
        let verticalVectors: [simd_float3] = [
            [ 0,  0.5, 0  ],
            [ 0,  0,   0.5],
            [ 0,  0.5, 0  ],
            [ 0,  0.5, 0  ],
            [ 0,  0,  -0.5],
            [ 0,  0.5, 0  ],
        ]
        
        let currentVertices = (0..<6).flatMap { sideID -> [CentralVertex] in
            let normalVector     = normalVectors    [sideID]
            let horizontalVector = horizontalVectors[sideID]
            let verticalVector   = verticalVectors  [sideID]
            
            let positions: [simd_float3] = [
                normalVector - horizontalVector - verticalVector,
                normalVector + horizontalVector - verticalVector,
                normalVector - horizontalVector + verticalVector,
                normalVector + horizontalVector + verticalVector
            ]
            
            let normal = normalVector + normalVector
            
            return positions.map {
                CentralVertex(position: $0, normal: normal)
            }
        }
        
        let currentIndices = (UInt16(0)..<6).flatMap { sideID -> [UInt16] in
            let baseIndex = sideID << 2
            
            return Self.makeQuadIndices([0, 1, 2, 3].map{ $0 + baseIndex})
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
    
    /**
     Moves and scales a ray so that the given bounding box becomes model space's bounding box.
     
     The minimum coordinates (first matrix column) map to `x = -0.5`, `y = -0.5`, and `z = -0.5`. The maximum coordinates (second matrix column) map to the same planes with `-0.5` replaced with `0.5`.
     */
    @inlinable
    func transformedIntoBoundingBox(_ boundingBox: simd_float2x3) -> RayTracing.Ray {
        var copy = self
        let translation = (boundingBox[0] + boundingBox[1]) * 0.5
        copy.origin -= translation
        
        let inverseScale = simd_fast_recip(boundingBox[1] - boundingBox[0])
        copy.origin *= inverseScale
        copy.direction *= inverseScale
        
        return copy
    }
    
    /// Intersects a cube confined to model space. Equivalent to intersecting model space's bounding box.
    @inlinable
    func getCubeProgress() -> Float? {
        var baseProgresses = getBoundingCoordinatePlaneProgresses()
        
        @inline(__always)
        func testBaseProgress(axis: Int, altAxis1: Int, altAxis2: Int) {
            guard !baseProgresses[axis].isNaN else { return }
            
            let projection3D = project(progress: baseProgresses[axis])
            let projection2D = simd_float2(projection3D[altAxis1], projection3D[altAxis2])
            
            if any(abs(projection2D) .> 0.5) {
                baseProgresses[axis] = .nan
            }
        }
        
        testBaseProgress(axis: 0, altAxis1: 1, altAxis2: 2)
        testBaseProgress(axis: 1, altAxis1: 0, altAxis2: 2)
        testBaseProgress(axis: 2, altAxis1: 0, altAxis2: 1)
        
        let possibleBaseProgress = baseProgresses.min()
        return possibleBaseProgress.isNaN ? nil : possibleBaseProgress
    }
    
}

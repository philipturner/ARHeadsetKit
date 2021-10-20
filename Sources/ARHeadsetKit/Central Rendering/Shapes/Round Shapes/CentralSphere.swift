//
//  CentralSphere.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/17/21.
//

import Metal
import simd

#if !os(macOS)
struct CentralSphere: CentralRoundShape {
    static let shapeType: ARShapeType = .sphere
    
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
        
        let numSlices = (numSegments + 1) >> 1
        let slices_end = numSlices - 1
        let multiplier = 1 / Float(numSlices)
        
        for i in 1..<slices_end {
            let sincos = __sincospif_stret(Float(i) * multiplier)
            
            currentVertices += circleVertices.map {
                let scaledPosition2D = $0 * sincos.__sinval
                let position = simd_float3(scaledPosition2D.x, 0.5 * sincos.__cosval, scaledPosition2D.y)
                
                return CentralVertex(position: position, normal: position + position)
            }
            
            currentIndices += Self.makeRoundSectionIndices(upperStart: currentIndexOffset, numSegments: numSegments)
            currentIndexOffset += numSegments
        }
        
        do {
            let sincos = __sincospif_stret(Float(slices_end) * multiplier)
            
            currentVertices += circleVertices.map {
                let scaledPosition2D = $0 * sincos.__sinval
                let position = simd_float3(scaledPosition2D.x, 0.5 * sincos.__cosval, scaledPosition2D.y)
                
                return CentralVertex(position: position, normal: position + position)
            }
            
            currentIndices += Self.makeRoundTipIndices(circleStart: currentIndexOffset, numSegments: numSegments, upward: false)
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
    
    /// Intersects a sphere confined to model space.
    @inlinable
    func getSphereProgress() -> Float? {
        var coefficients = dotAdd(direction, direction,
                                  direction, origin,
                                  origin,    origin, rhs2: -0.25)
        
        coefficients[2] *= coefficients[0]
        
        guard let progress = finishRoundShapeProgress(coefficients[1], coefficients[2]) else {
            return nil
        }
        
        return progress / coefficients[0]
    }
    
}

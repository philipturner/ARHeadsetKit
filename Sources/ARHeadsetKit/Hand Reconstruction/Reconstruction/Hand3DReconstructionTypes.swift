//
//  Hand3DReconstructionTypes.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/15/21.
//

import Foundation
import simd

protocol HandOcclusionShape {
    func contains(_ point: simd_float2) -> Bool
}

extension HandRenderer {
    
    struct Circle: HandOcclusionShape {
        var center: simd_float2
        var radiusSquared: Float
        
        init(center: simd_float2, radius: Float) {
            self.center = center
            radiusSquared = radius * radius
        }
        
        func contains(_ point: simd_float2) -> Bool {
            length_squared(point - center) <= radiusSquared
        }
    }
    
    struct Rectangle: HandOcclusionShape {
        var a: simd_float2
        var b: simd_float2
        var radius: Float
        
        var line: simd_float2
        var normal: simd_float2
        
        init(a: simd_float2, b: simd_float2, radius: Float) {
            (self.a, self.b, self.radius) = (a, b, radius)
            line = b - a
            normal = normalize(simd_float2(-line.y, line.x))
        }
        
        func contains(_ point: simd_float2) -> Bool {
            if dot(point - b, line) > 0 { return false }
            if dot(point - a, line) < 0 { return false }
            
            return abs(dot(point - a, normal)) <= radius
        }
    }
    
    struct Triangle: HandOcclusionShape {
        var a: simd_float2
        var b: simd_float2
        var c: simd_float2
        
        func contains(_ point: simd_float2) -> Bool {
            let signAB = simd_determinant(simd_float2x2(b - a, point - a)) > 0
            let signBC = simd_determinant(simd_float2x2(c - b, point - b)) > 0
            
            guard signAB == signBC else {
                return false
            }
            
            let signCA = simd_determinant(simd_float2x2(a - c, point - c)) > 0
            
            return signAB == signCA
        }
    }
    
    struct Joint: HandOcclusionShape {
        var circle: Circle
        var rectangle: Rectangle
        
        func contains(_ point: simd_float2) -> Bool {
            rectangle.contains(point) || circle.contains(point)
        }
    }
    
    struct Finger: HandOcclusionShape {
        var joints: [Joint]
        var connections: [HandOcclusionShape]
        
        func contains(_ point: simd_float2) -> Bool {
            contains(point, testingConnections: true)
        }
        
        func contains(_ point: simd_float2, testingConnections: Bool) -> Bool {
            if joints.contains(where: { $0.contains(point) }) {
                return true
            }
            
            if testingConnections {
                return connections.contains(where: { $0.contains(point) })
            } else {
                return false
            }
        }
        
        func testInternalOcclusion(_ point: simd_float2, jointID: Int, upward: Bool) -> Bool {
            if upward {
                return joints[0..<jointID].contains(where: { $0.contains(point) })
            }
            
            if jointID == 3 { return false }
            
            if joints[jointID + 1..<4].contains(where: { $0.circle.contains(point) }) {
                return true
            }
            
            if jointID == 2 { return false }
            
            return joints[jointID + 2..<4].contains(where: { $0.rectangle.contains(point) })
        }
    }
    
    typealias IndexPair = (Int, Int)
    typealias TestableIndexPair = (IndexPair, IndexPair)
    
    struct OcclusionInfo {
        var visiblePoints = [Int]()
        var occludedPoints = [Int]()
        var globalVisibleIndices = [Int]()
        var plane: RayTracing.Plane?
    }
    
}

protocol RenderableHand {
    var optionalComponents: [HandRenderer.HandComponent?] { get }
}

extension HandRenderer {
    
    typealias HandComponent = [simd_float3]
    
    struct ReconstructedHand: RenderableHand {
        private var _booleanMask = UInt8(0)
        var isRight: Bool { _booleanMask & 1 != 0 }
        var isOnlyWrist: Bool { _booleanMask & 2 != 0 }
        
        var components: [HandComponent?] = Array(repeating: nil, count: 6)
        var optionalComponents: [HandComponent?] { components }
        
        var directionsAreReliable = false
        var palmTangentWasBackwards: Bool!
        
        var palmTangent: simd_float3?
        var upDirection: simd_float3?
        var thumbKnuckle: simd_float3?
        var thumbJoint1: simd_float3?
        
        private var componentsHaveBeenTransformed = false
        
        init(isRight: Bool, components: [HandComponent?] = Array(repeating: nil, count: 6)) {
            if !components[1..<6].contains(where: { $0 != nil }) {
                _booleanMask = isRight ? 3 : 2
            } else {
                _booleanMask = isRight ? 1 : 0
            }
            
            self.components = components
        }
        
        var numValidComponents: Int {
            components.reduce(0){ $1 == nil ? $0 : $0 + 1 }
        }
        
        mutating func checkPointDepths(centerDepth: Float) {
            assert(!componentsHaveBeenTransformed)
            
            for i in 0..<5 {
                guard let component = components[i] else {
                    return
                }
                
                for joint in component {
                    let depth = -joint.z
                    
                    if depth < 0 || abs(depth - centerDepth) > 0.15 || depth > 0.8 {
                        components[i] = nil
                        return
                    }
                }
            }
        }
        
        mutating func transformPoints(transformDuringSample transform: simd_float4x4) {
            if componentsHaveBeenTransformed {
                return
            } else {
                componentsHaveBeenTransformed = true
            }
            
            if let palmTangent = palmTangent {
                palmTangentWasBackwards = dot(palmTangent, [0, 0, 1]) < -0.3
            }
            
            for i in 0..<6 {
                guard let component = components[i] else {
                    continue
                }
                
                components[i] = component.map{ simd_make_float3(transform * simd_float4($0, 1)) }
            }
            
            func transformComponent(_ point: inout simd_float3?, _ w: Float) {
                if point != nil {
                    point = simd_make_float3(transform * simd_float4(point!, w))
                }
            }
            
            transformComponent(&palmTangent,  0)
            transformComponent(&upDirection,  0)
            transformComponent(&thumbKnuckle, 1)
            transformComponent(&thumbJoint1,  1)
        }
    }
    
}

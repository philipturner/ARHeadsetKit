//
//  CentralShape.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/17/21.
//

import Metal
import simd

#if !os(macOS)
@usableFromInline
struct CentralVertex {
    var position: simd_float3
    var normal: simd_half3
    
    init(position: simd_float3, normal: simd_float3) {
        self.position = position
        self.normal = simd_half3(normal)
    }
}
#endif

public enum CentralShapeType: Int {
    case cube = 0
    case squarePyramid = 1
    case octahedron = 2
    
    case sphere = 3
    case cone = 4
    case cylinder = 5
    
    public var isPolyhedral: Bool {
        rawValue < 3
    }
}

public extension String {
    init(_ centralShapeType: CentralShapeType) {
        switch centralShapeType {
        case .cube:          self = "Cube"
        case .squarePyramid: self = "Square Pyramid"
        case .octahedron:    self = "Octahedron"
            
        case .sphere:        self = "Sphere"
        case .cone:          self = "Cone"
        case .cylinder:      self = "Cylinder"
        }
    }
}

#if !os(macOS)
protocol CentralShape {
    static var shapeType: CentralShapeType { get }
    
    var numIndices: Int { get }
    var normalOffset: Int { get set }
    var indexOffset: Int { get set }
    
    init(centralRenderer: CentralRenderer, numSegments: UInt16,
         vertices: inout [CentralVertex], indices: inout [UInt16])
    
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>)
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>, desiredLOD: Int)
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>, desiredLOD: Int,
                               userDistanceEstimate: Float)
}

protocol CentralPolyhedralShape: CentralShape { }

extension CentralPolyhedralShape {
    
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>) {
        let userDistance = shapeContainer.centralRenderer.getDistance(of: object)
        shapeContainer.aliases[0].append(object.alias, userDistance: userDistance)
    }
    
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>, desiredLOD: Int) {
        appendAlias(of: object, to: &shapeContainer)
    }
    
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>, desiredLOD: Int,
                               userDistanceEstimate: Float) {
        shapeContainer.aliases[0].append(object.alias, userDistance: userDistanceEstimate)
    }
    
}

protocol CentralRoundShape: CentralShape { }

extension CentralRoundShape {
    
    @inline(__always)
    private static func findShapeIndex<T>(lod: Int, shapeContainer: CentralRenderer.ShapeContainer<T>) -> Int {
        var lowerBound = 0
        var upperBound = shapeContainer.sizeRange.count - 1
        
        while lowerBound < upperBound {
            let midPoint = (lowerBound + upperBound + 1) >> 1
            
            if shapeContainer.sizeRange[midPoint] > lod {
                upperBound = midPoint - 1
            } else {
                lowerBound = midPoint
            }
        }
        
        return lowerBound
    }
    
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>) {
        let (desiredLOD, userDistance) = shapeContainer.centralRenderer.getDistanceAndLOD(of: object)
        
        let shapeIndex = findShapeIndex(lod: desiredLOD, shapeContainer: shapeContainer)
        shapeContainer.aliases[shapeIndex].append(object.alias, userDistance: userDistance)
    }
    
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>, desiredLOD: Int) {
        let userDistance = shapeContainer.centralRenderer.getDistance(of: object)
        
        let shapeIndex = findShapeIndex(lod: desiredLOD, shapeContainer: shapeContainer)
        shapeContainer.aliases[shapeIndex].append(object.alias, userDistance: userDistance)
    }
    
    static func appendAlias<T>(of object: ARObject, to shapeContainer: inout CentralRenderer.ShapeContainer<T>, desiredLOD: Int,
                               userDistanceEstimate: Float) {
        let shapeIndex = findShapeIndex(lod: desiredLOD, shapeContainer: shapeContainer)
        shapeContainer.aliases[shapeIndex].append(object.alias, userDistance: userDistanceEstimate)
    }
    
}



extension CentralShape {
    
    static func makeQuadIndices(lowerLeft: UInt16, lowerRight: UInt16, upperLeft: UInt16, upperRight: UInt16) -> [UInt16] {
        [lowerLeft, lowerRight, upperRight,
         lowerLeft, upperRight, upperLeft]
    }
    
    static func makeQuadIndices(_ input: [UInt16]) -> [UInt16] {
        makeQuadIndices(lowerLeft: input[0], lowerRight: input[1], upperLeft: input[2], upperRight: input[3])
    }
    
    static func makeRoundSectionIndices(upperStart: UInt16, numSegments: UInt16) -> [UInt16] {
        let lowerStart = upperStart + numSegments
        let numSegments_minus1 = numSegments - 1
        
        let indices = (0..<numSegments_minus1).flatMap { segmentID -> [UInt16] in
            let lowerLeft = lowerStart + segmentID
            let upperLeft = upperStart + segmentID
            
            return makeQuadIndices(lowerLeft: lowerLeft, lowerRight: lowerLeft + 1,
                                   upperLeft: upperLeft, upperRight: upperLeft + 1)
        }
        
        let lastQuad = makeQuadIndices(lowerLeft: lowerStart + numSegments_minus1, lowerRight: lowerStart,
                                       upperLeft: upperStart + numSegments_minus1, upperRight: upperStart)
        return indices + lastQuad
    }
    
    static func makeRoundTipIndices(circleStart: UInt16, numSegments: UInt16, upward: Bool) -> [UInt16] {
        let numSegments_minus1 = numSegments - 1
        
        let indices: [UInt16]
        let lastTriangle: [UInt16]
        
        if upward {
            let tip = circleStart - 1
            
            indices = (0..<numSegments_minus1).flatMap { segmentID -> [UInt16] in
                let circumferenceStart = circleStart + segmentID
                
                return [circumferenceStart, circumferenceStart + 1, tip]
            }
            
            lastTriangle = [circleStart + numSegments_minus1, circleStart, tip]
        } else {
            let tip = circleStart + numSegments
            
            indices = (0..<numSegments_minus1).flatMap { segmentID -> [UInt16] in
                let circumferenceStart = circleStart + segmentID
                
                return [circumferenceStart, tip, circumferenceStart + 1]
            }
            
            lastTriangle = [circleStart + numSegments_minus1, tip, circleStart]
        }
        
        return indices + lastTriangle
    }
    
    static func makePointedTipIndices(upperStart: UInt16, numSegments: UInt16, upward: Bool) -> [UInt16] {
        let lowerStart = upperStart + numSegments
        let numSegments_minus1 = numSegments - 1
        
        let indices: [UInt16]
        let lastTriangle: [UInt16]
        
        if upward {
            indices = (0..<numSegments_minus1).flatMap { segmentID -> [UInt16] in
                let lowerLeft  = lowerStart + segmentID
                let upperIndex = upperStart + segmentID
                
                return [upperIndex, lowerLeft, lowerLeft + 1]
            }
            
            let lowerLeft  = lowerStart + numSegments_minus1
            let upperIndex = upperStart + numSegments_minus1
            
            lastTriangle = [upperIndex, lowerLeft, lowerStart]
        } else {
            indices = (0..<numSegments_minus1).flatMap { segmentID -> [UInt16] in
                let lowerLeft  = lowerStart + segmentID
                let upperIndex = upperStart + segmentID
                
                return [upperIndex, lowerLeft + 1, lowerLeft]
            }
            
            let lowerLeft  = lowerStart + numSegments_minus1
            let upperIndex = upperStart + numSegments_minus1
            
            lastTriangle = [upperIndex, lowerStart, lowerLeft]
        }
        
        return indices + lastTriangle
    }
    
}

extension CentralRenderer {
    
    typealias GeometryBufferReturn = (geometryBuffer: MTLBuffer, normalOffset: Int, indexOffset: Int)
    
    func makeGeometryBuffer<T: CentralShape>(_ type: T.Type, _ vertices: [CentralVertex], _ indices: [UInt16]) -> GeometryBufferReturn {
        let vertexBufferSize = vertices.count * MemoryLayout<simd_float3>.stride
        let normalBufferSize = vertices.count * MemoryLayout<simd_half3>.stride
        let indexBufferSize  = indices.count  * MemoryLayout<UInt16>.stride
        
        let normalOffset = vertexBufferSize
        let indexOffset = normalOffset + normalBufferSize
        
        let geometryBufferSize = indexOffset + indexBufferSize
        let geometryBuffer = device.makeBuffer(length: geometryBufferSize, options: .storageModeShared)!
        let geometryPointer = geometryBuffer.contents()
        
        let vertexPointer = geometryPointer.assumingMemoryBound(to: simd_float3.self)
        
        if type == CentralCylinder.self {
            let normalPointer = (geometryPointer + normalOffset).assumingMemoryBound(to: simd_half4.self)
            
            for i in 0..<vertices.count {
                let retrievedVertex = vertices[i]
                
                let attributeMask: UInt16 = (retrievedVertex.position.y    > 0   ? 1 : 0)
                                          | (abs(retrievedVertex.normal.y) < 0.1 ? 2 : 0)
                
                vertexPointer[i] = retrievedVertex.position
                normalPointer[i] = simd_half4(retrievedVertex.normal, .init(bitPattern: attributeMask))
            }
        } else {
            let normalPointer = (geometryPointer + normalOffset).assumingMemoryBound(to: simd_half3.self)
            
            for i in 0..<vertices.count {
                let retrievedVertex = vertices[i]
                
                vertexPointer[i] = retrievedVertex.position
                normalPointer[i] = retrievedVertex.normal
            }
        }
        
        let indexPointer = (geometryPointer + indexOffset) .assumingMemoryBound(to: UInt16.self)
        memcpy(indexPointer, indices.withUnsafeBytes{ $0.baseAddress! }, indices.count * MemoryLayout<UInt16>.stride)
        
        return (geometryBuffer, normalOffset, indexOffset)
    }
    
}
#endif

//
//  CentralShapeContainer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/18/21.
//

import Metal
import simd

protocol CentralShapeContainer {
    var centralRenderer: CentralRenderer { get }
    
    static var shapeType: CentralShapeType { get }
    var sizeRange: [Int] { get }
    var shapes: [CentralShape] { get }
    
    var aliases: [CentralAliasContainer] { get set }
    var numAliases: Int { get set }
    
    var uniformBuffer: MTLLayeredBuffer<CentralRenderer.UniformLayer> { get set }
    
    var normalOffset: Int { get }
    var indexOffset: Int { get }
    var geometryBuffer: MTLBuffer { get }
    
    init(centralRenderer: CentralRenderer, range: [Int])
    
    mutating func appendAlias(of object: ARObject)
    mutating func appendAlias(of object: ARObject, desiredLOD: Int)
    mutating func appendAlias(of object: ARObject, desiredLOD: Int, userDistanceEstimate: Float)
}

extension CentralShapeContainer {
    var renderer: MainRenderer { centralRenderer.renderer }
    var device: MTLDevice { centralRenderer.device }
    var renderIndex: Int { centralRenderer.renderIndex }
    
    var usingHeadsetMode: Bool { centralRenderer.usingHeadsetMode }
    var shapeContainers: [CentralShapeContainer] { centralRenderer.shapeContainers }
    
    var lodTransform: simd_float4x4 { centralRenderer.lodTransform }
    var lodTransform2: simd_float4x4 { centralRenderer.lodTransform2 }
    var lodTransformInverse: simd_float4x4 { centralRenderer.lodTransformInverse }
    var lodTransformInverse2: simd_float4x4 { centralRenderer.lodTransformInverse2 }
    
    typealias VertexUniforms      = CentralRenderer.VertexUniforms
    typealias HeadsetModeUniforms = CentralRenderer.HeadsetModeUniforms
    typealias FragmentUniforms    = CentralRenderer.FragmentUniforms
}

struct CentralAliasContainer: ExpressibleByArrayLiteral {
    typealias ArrayLiteralElement = Never
    typealias Alias = ARObject.Alias
    
    var closeAliases: [Alias]
    var farAliases: [Alias]
    var count: Int { closeAliases.count + farAliases.count }
    
    init(arrayLiteral elements: Never...) {
        closeAliases = []
        farAliases = []
    }
    
    mutating func removeAll() {
        closeAliases.removeAll(keepingCapacity: true)
        farAliases.removeAll(keepingCapacity: true)
    }
    
    func forEach(_ body: (ARObject.Alias) throws -> Void) rethrows {
        try! closeAliases.forEach(body)
        try! farAliases.forEach(body)
    }
    
    mutating func append(_ alias: Alias, userDistance: Float) {
        if userDistance <= 0.15, alias.allowsViewingInside {
            closeAliases.append(alias)
        } else {
            farAliases.append(alias)
        }
    }
}

extension CentralRenderer {
    
    enum UniformLayer: UInt16, MTLBufferLayer {
        case vertex
        case fragment
        
        static let bufferLabel = "Central Shape Uniform Buffer"
        
        func getSize(capacity: Int) -> Int {
            switch self {
            case .vertex:   return capacity * MainRenderer.numRenderBuffers * MemoryLayout<HeadsetModeUniforms>.stride
            case .fragment: return capacity * MainRenderer.numRenderBuffers * MemoryLayout<FragmentUniforms>.stride
            }
        }
    }
    
    struct ShapeContainer<Shape: CentralShape>: CentralShapeContainer {
        unowned let centralRenderer: CentralRenderer
        
        static var shapeType: CentralShapeType { Shape.shapeType }
        var sizeRange: [Int]
        var shapes: [CentralShape]
        
        var aliases: [CentralAliasContainer]
        var numAliases = 0
        
        var uniformBuffer: MTLLayeredBuffer<UniformLayer>
        
        var normalOffset: Int
        var indexOffset: Int
        var geometryBuffer: MTLBuffer
        
        mutating func appendAlias(of object: ARObject) {
            numAliases += 1
            Shape.appendAlias(of: object, to: &self)
        }
        
        mutating func appendAlias(of object: ARObject, desiredLOD: Int) {
            numAliases += 1
            Shape.appendAlias(of: object, to: &self, desiredLOD: desiredLOD)
        }
        
        mutating func appendAlias(of object: ARObject, desiredLOD: Int, userDistanceEstimate: Float) {
            numAliases += 1
            Shape.appendAlias(of: object, to: &self, desiredLOD: desiredLOD, userDistanceEstimate: userDistanceEstimate)
        }
        
        
        init(centralRenderer: CentralRenderer, range: [Int] = [1]) {
            self.centralRenderer = centralRenderer
            let device = centralRenderer.device
            
            let shapeCapacity = 4
            uniformBuffer = device.makeLayeredBuffer(capacity: shapeCapacity, options: [.cpuCacheModeWriteCombined, .storageModeShared])
            
            aliases = Array(repeating: [], count: range.count)
            
            
            
            sizeRange = range
            
            var vertices = [CentralVertex]()
            var indices = [UInt16]()
            
            shapes = range.map {
                 Shape(centralRenderer: centralRenderer, numSegments: UInt16($0), vertices: &vertices, indices: &indices)
            }
            
            (geometryBuffer, normalOffset, indexOffset) = centralRenderer.makeGeometryBuffer(Shape.self, vertices, indices)
            
            debugLabel {
                uniformBuffer .label = "Central \(String(Shape.shapeType)) Uniform Buffer"
                geometryBuffer.label = "Central \(String(Shape.shapeType)) Geometry Buffer"
                
                geometryBuffer.addDebugMarker("Vertices", range: 0..<normalOffset)
                geometryBuffer.addDebugMarker("Normals",  range: normalOffset..<indexOffset)
                geometryBuffer.addDebugMarker("Indices",  range: indexOffset..<geometryBuffer.length)
            }
        }
    }
    
}

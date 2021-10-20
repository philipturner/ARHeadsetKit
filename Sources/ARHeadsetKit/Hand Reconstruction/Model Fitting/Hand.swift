//
//  Hand.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/27/21.
//

#if !os(macOS)
import Foundation
import simd

extension ProcessInfo {
    
    var thermalStateColor: simd_float3 {
        switch thermalState {
        case .nominal:  return [0.100, 0.100, 0.800]
        case .fair:     return [0.100, 0.800, 0.100]
        case .serious:  return [0.550, 0.550, 0.100]
        case .critical: return [0.800, 0.100, 0.100]
        @unknown default: fatalError("This thermal state is not possible!")
        }
    }
    
}

extension ProcessInfo.ThermalState {
    
    var description: String {
        switch self {
        case .nominal:  return "Nominal"
        case .fair:     return "Fair"
        case .serious:  return "Serious"
        case .critical: return "Critical"
        @unknown default: fatalError("This thermal state is not possible!")
        }
    }
    
}

struct Hand {
    typealias HandComponent = HandRenderer.HandComponent
    var components: [HandComponent]
    var fingerAngles: [simd_float3]
    
    var palmTangent: simd_float3
    var upDirection: simd_float3
    var palmNormal: simd_float3
    
    var center: simd_float3
    
    func getWireframeObjects(color: simd_float3 = ProcessInfo.processInfo.thermalStateColor) -> [ARObject] {
        var objects = [ARObject](capacity: 43)
        objects += (0..<6).flatMap{ getComponentObjects(componentID: $0, color: color) }
        
        let wristToFingerConnections = (1...5).map {
            ((0, 0), ($0, 0))
        }
        
        let knuckleConnections = (1...4).map {
            (($0, 0), ($0 + 1, 0))
        }
        
        let connections = wristToFingerConnections + knuckleConnections
        
        objects += connections.compactMap {
            let start = components[$0.0.0][$0.0.1]
            let end   = components[$0.1.0][$0.1.1]
            
            return getConnectionObject(start: start, end: end, color: color)
        }
        
        return objects
    }
    
    func getJointObject(position: simd_float3, color: simd_float3) -> ARObject {
        ARObject(shapeType: .sphere,
                 position: position,
                 scale: simd_float3(repeating: 0.015),
                 
                 color: color,
                 shininess: 8)
    }
    
    func getConnectionObject(start: simd_float3, end: simd_float3, color: simd_float3) -> ARObject? {
        ARObject(roundShapeType: .cylinder,
                 bottomPosition: start,
                 topPosition: end,
                 diameter: 0.012,
                 
                 color: color,
                 shininess: 8)
    }
    
    func getComponentObjects(componentID: Int, color: simd_float3) -> [ARObject] {
        let component = components[componentID]
        
        var cachedPosition = component[0]
        var output = [ getJointObject(position: cachedPosition, color: color) ]
        
        for currentPosition in component[0..<component.count] {
            if let connection = getConnectionObject(start: cachedPosition, end: currentPosition, color: color) {
                output.append(connection)
                output.append(getJointObject(position: currentPosition, color: color))
            }
            
            cachedPosition = currentPosition
        }
        
        return output
    }
    
    func getDirectionObjects() -> [ARObject] {
        var output = [ARObject](capacity: 10)
        
        func makeArrow(direction: simd_float3, start: simd_float3 = center,
                       size: Float = 0.055, color: simd_float3) {
            let baseEnd = fma(direction, max(0.005, size - 0.015), start)
            
            if let base = ARObject(roundShapeType: .cylinder,
                                   bottomPosition: start,
                                   topPosition: baseEnd,
                                   diameter: 0.0105,
                                   
                                   color: color,
                                   shininess: 8) {
                output.append(base)
            }
            
            let tipEnd = fma(direction, simd_float3(repeating: 0.015), baseEnd)
            
            if let tip = ARObject(roundShapeType: .cone,
                                  bottomPosition: baseEnd,
                                  topPosition:     tipEnd,
                                  diameter: 0.015,
                                  
                                  color: color,
                                  shininess: 8) {
                output.append(tip)
            }
        }
        
        makeArrow(direction: palmTangent, color: [0.7, 0.1, 0.1])
        makeArrow(direction: upDirection, color: [0.1, 0.7, 0.1])
        makeArrow(direction: palmNormal,  color: [0.1, 0.1, 0.7])
        
        return output
    }
    
    func getCenterObject() -> ARObject {
        ARObject(shapeType: .sphere,
                 position: center,
                 scale: simd_float3(repeating: 0.04),
                 
                 color: [0.8, 0.8, 0.8],
                 shininess: 8)
    }
}
#endif

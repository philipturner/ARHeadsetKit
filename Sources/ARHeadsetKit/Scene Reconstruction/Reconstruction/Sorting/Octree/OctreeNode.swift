//
//  OctreeNode.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import simd

struct OctreeNode: Equatable {
    var count: UInt32
    var offset: UInt32
    var centerAndSize: simd_float4
    var nextNodes: [OctreeNode?]!
    
    init(count: UInt32, offset: UInt32 = .max, centerAndSize: simd_float4 = [0, 0, 0, -1], nextNodes: [OctreeNode?]? = nil) {
        self.count = count
        self.offset = offset
        self.centerAndSize = centerAndSize
        self.nextNodes = nextNodes
    }
    
    init(_ count: UInt32, _ offset: UInt32 = .max, _ centerAndSize: simd_float4 = [0, 0, 0, -1], _ nextNodes: [OctreeNode?]? = nil) {
        self.init(count: count, offset: offset, centerAndSize: centerAndSize, nextNodes: nextNodes)
    }
    
    var center: simd_float3 {
        simd_float3(centerAndSize.x, centerAndSize.y, centerAndSize.z)
    }
    
    var size: Float {
        centerAndSize.w
    }
    
    var largestSize: Float {
        guard let nextNodes_copy = nextNodes else {
            return size
        }
        
        if size == -1 {
            var maxSize: Float = -1
            
            for i in 0..<8 {
                maxSize = max(maxSize, nextNodes_copy[i]?.largestSize ?? -1)
            }
            
            return maxSize
        } else {
            return nextNodes_copy.first(where: { $0 != nil })!!.largestSize
        }
    }
    
    var worldOctantSize: Float {
        nextNodes.compactMap{ $0?.size }.max()!
    }
    
    static func worldOctantID(for center: simd_float3) -> Int {
        var out = 0
        
        if center.x < 0 { out += 4 }
        if center.y < 0 { out += 2 }
        if center.z < 0 { out += 1 }
        
        return out
    }
    
    static func normalizedOffset(for worldOctantID: Int) -> simd_float3 {
        let cubeCorners: [simd_float3] = [[ 0.5,  0.5,  0.5],
                                          [ 0.5,  0.5, -0.5],
                                          [ 0.5, -0.5,  0.5],
                                          [ 0.5, -0.5, -0.5],
                                          [-0.5,  0.5,  0.5],
                                          [-0.5,  0.5, -0.5],
                                          [-0.5, -0.5,  0.5],
                                          [-0.5, -0.5, -0.5]]
        return cubeCorners[worldOctantID]
    }
    
    var stringValue: String {
        var selfString = "Center - (0, 0, 0, -1) - (\(offset), \(count))"
        
        if nextNodes == nil {
            return selfString
        }
        
        selfString += "\n\n"
        
        for i in 0..<nextNodes.count {
            guard let node = nextNodes[i] else {
                continue
            }
            
            let childString = node.getString(pathIndex: i, tabDepth: 0)
            
            selfString += childString
        }
        
        selfString.removeLast()
        
        return selfString
    }
    
    func getString(pathIndex: Int, tabDepth: Int) -> String {
        func makeTabString(tabDepth: Int) -> String {
            var output = ""
            
            for _ in 0..<tabDepth {
                output.append("\t")
            }
            
            return output
        }
        
        var selfString = String(pathIndex) + " - (" + .init(Int(centerAndSize.x)) + ", "
                                                    + .init(Int(centerAndSize.y)) + ", "
                                                    + .init(Int(centerAndSize.z)) + ", "
                                                    + .init(Int(centerAndSize.w)) + ") - ("
                                                    + .init(offset) + ", " + .init(count) + ")"
        
        selfString = makeTabString(tabDepth: tabDepth) + selfString + "\n"
        
        if nextNodes == nil {
            return selfString
        }
        
        for i in 0..<nextNodes.count {
            guard let node = nextNodes[i] else {
                continue
            }
            
            let childString = node.getString(pathIndex: i, tabDepth: tabDepth + 1)
            
            selfString += childString
        }
        
        return selfString
    }
    
}
#endif

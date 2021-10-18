//
//  OctreeNodeExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import simd

extension OctreeNode {
    
    mutating func expandToSize(_ newSize: Float) {
        if newSize == size {
            return
        } else if size == -1 {
            for i in 0..<8 {
                nextNodes[i]?.expandToSize(newSize)
            }
            
            return
        }
        
        if newSize > 2 * size {
            expandToSize(newSize * 0.5)
        }
        
        var newNextNodes = [OctreeNode?](repeating: nil, count: 8)
        
        let worldOctantID = Self.worldOctantID(for: center)
        newNextNodes[7 - worldOctantID] = self
        
        self = OctreeNode(count, offset, simd_float4(center * 2, newSize), newNextNodes)
    }
    
    typealias ArrayElement = (path: [UInt32], node: Self)
    
    var array: [ArrayElement] {
        getArray()
    }
    
    private func getArray(currentPath: [UInt32] = []) -> [ArrayElement] {
        if nextNodes == nil {
            return [(currentPath, self)]
        } else {
            return (0..<8).flatMap { i -> [ArrayElement] in
                guard let nextNode = nextNodes[i] else {
                    return []
                }
                
                return nextNode.getArray(currentPath: currentPath + [UInt32(i)])
            }
        }
    }
    
    private func selectNode(path: [UInt32], arrayIterator: inout Int) -> Self? {
        guard arrayIterator < path.count else {
            return self
        }
        
        guard let nextNodes = nextNodes,
              let nextNode  = nextNodes[Int(path[arrayIterator])] else {
            return nil
        }
        
        arrayIterator += 1
        
        return nextNode.selectNode(path: path, arrayIterator: &arrayIterator)
    }
    
    func selectNode(path: [UInt32]) -> Self? {
        var arrayIterator = 0
        
        return selectNode(path: path, arrayIterator: &arrayIterator)
    }
    
    static func reconstructOctree(_ array: [ArrayElement], octantSize: Float) -> Self {
        var firstNode = OctreeNode(count: 0, offset: 0)
        
        var arrayIterator = 0
        var currentPath = [UInt32]()
        
        firstNode.nextNodes = [OctreeNode?](repeating: nil, count: 8)
        
        while arrayIterator < array.count {
            let nextElement = array[arrayIterator]
            
            let worldOctantID = Self.worldOctantID(for: nextElement.node.center)
            currentPath.append(UInt32(worldOctantID))
            
            var nextNode: OctreeNode
            
            if nextElement.path.count == currentPath.count {
                arrayIterator += 1
                
                nextNode = nextElement.node
            } else {
                let spaceOffset = Self.normalizedOffset(for: worldOctantID) * octantSize
                
                nextNode = OctreeNode(count: 0, centerAndSize: simd_float4(spaceOffset, octantSize))
                nextNode.appendNodes(array, arrayIterator: &arrayIterator, currentPath: &currentPath)
            }
            currentPath.removeLast()
            
            firstNode.count += nextNode.count
            firstNode.nextNodes[worldOctantID] = nextNode
        }
        
        return firstNode
    }
    
    mutating func appendNodes(_ array: [ArrayElement], arrayIterator: inout Int, currentPath: inout [UInt32]) {
        while arrayIterator < array.count {
            let nextElement = array[arrayIterator]
            
            if nextElement.path.count <= currentPath.count {
                return
            } else if nextElement.path.count == currentPath.count + 1 {
                if currentPath.elementsEqual(nextElement.path[0..<currentPath.count]) {
                    arrayIterator += 1
                    
                    if nextNodes == nil {
                        nextNodes = [OctreeNode?](repeating: nil, count: 8)
                    }
                    
                    let worldOctantID = Self.worldOctantID(for: nextElement.node.center - center)
                    
                    count += nextElement.node.count
                    
                    if offset == .max {
                        offset = nextElement.node.offset
                    }
                    
                    nextNodes[worldOctantID] = nextElement.node
                } else {
                    return
                }
            } else if currentPath.elementsEqual(nextElement.path[0..<currentPath.count]) {
                if nextNodes == nil {
                    nextNodes = [OctreeNode?](repeating: nil, count: 8)
                }
                
                let worldOctantID = Self.worldOctantID(for: nextElement.node.center - center)
                
                let size_half = size * 0.5
                let spaceOffset = Self.normalizedOffset(for: worldOctantID) * size_half
                
                var nextNode = OctreeNode(count: 0, centerAndSize: simd_float4(center + spaceOffset, size_half))
                
                currentPath.append(UInt32(worldOctantID))
                nextNode.appendNodes(array, arrayIterator: &arrayIterator, currentPath: &currentPath)
                currentPath.removeLast()
                
                count += nextNode.count
                
                if offset == .max {
                    offset = nextNode.offset
                }
                
                nextNodes[worldOctantID] = nextNode
            } else {
                return
            }
        }
    }
    
}


//
//  Hand3DReconstructionUtilities.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/15/21.
//

import simd

extension HandRenderer {
    
    func testOcclusions(points2D: [simd_float2], isFront: Bool) -> [Bool] {
        let radius = Float(0.01)
        
        let fingers = (0..<5).map { fingerID -> Finger in
            var connections = [HandOcclusionShape]()
            let fingerIndexOffset = fingerID << 2 + 1
            
            let joints = (0..<4).map { jointID -> Joint in
                let index = fingerIndexOffset + jointID
                let currentPoint = points2D[index]
                let lastPoint = (jointID == 0) ? points2D[0] : points2D[index - 1]
                
                if fingerID != 4, jointID == 0 {
                    let otherPoint = points2D[index + 4]
                    connections.append(Triangle(a: lastPoint, b: currentPoint, c: otherPoint))
                    
                    if fingerID != 0 {
                        connections.append(Rectangle(a: currentPoint, b: otherPoint, radius: radius))
                    }
                }
                
                if fingerID == 0, jointID == 1 {
                    let otherPoint = points2D[5]
                    
                    connections.append(Triangle (a: lastPoint,  b: currentPoint, c: otherPoint))
                    connections.append(Rectangle(a: currentPoint, b: otherPoint, radius: radius))
                }
                
                let circle = Circle(center: currentPoint, radius: radius)
                let rectangle = Rectangle(a: lastPoint, b: currentPoint, radius: radius)
                
                return Joint(circle: circle, rectangle: rectangle)
            }
            
            return Finger(joints: joints, connections: connections)
        }
        
        var occlusionTests = [Bool](repeating: false, count: 21)
        let wrist = points2D[0]
        
        for finger in fingers {
            if finger.testInternalOcclusion(wrist, jointID: 1, upward: false) {
                occlusionTests[0] = true
                break
            }
        }
        
        for fingerID in 0..<5 {
            let fingerIndexOffset = fingerID << 2 + 1
            
            (0..<4).forEach { jointID in
                let index = fingerIndexOffset + jointID
                let point = points2D[index]
                
                if fingers[fingerID].testInternalOcclusion(point, jointID: jointID, upward: !isFront) {
                    occlusionTests[index] = true
                    return
                }
                
                if fingerID == 0 {
                    guard jointID == 2 || jointID == 3 else {
                        return
                    }
                    
                    for finger in fingers[1..<5] {
                        if finger.contains(point, testingConnections: true) {
                            occlusionTests[index] = true
                            return
                        }
                    }
                    
                    for shape in fingers[0].connections {
                        if shape.contains(point) {
                            occlusionTests[index] = true
                            return
                        }
                    }
                } else {
                    for i in 0..<fingerID {
                        if fingers[i].contains(point, testingConnections: (i < fingerID - 1) || (jointID > 0)) {
                            occlusionTests[index] = true
                            return
                        }
                    }
                }
            }
        }
        
        return occlusionTests
    }
    
    func processOcclusionTests(points3D: [simd_float3], occlusionTests: [Bool]) -> [OcclusionInfo] {
        (0..<5).map { fingerID -> OcclusionInfo in
            let fingerIndexOffset = fingerID << 2 + 1
            
            var out = OcclusionInfo()
            
            for jointID in 0..<4 {
                let index = fingerIndexOffset + jointID
                
                if occlusionTests[index] {
                    out.occludedPoints.append(jointID)
                } else {
                    out.visiblePoints.append(jointID)
                    out.globalVisibleIndices.append(index)
                }
            }
            
            if out.globalVisibleIndices.count >= 2 {
                var indexPairs = [IndexPair]()
                
                if fingerID == 0 || fingerID == 2, !(occlusionTests[0] || occlusionTests[fingerIndexOffset]) {
                    indexPairs.append((0, fingerIndexOffset))
                }
                
                indexPairs += out.globalVisibleIndices[0..<out.globalVisibleIndices.count - 1].map{ ($0, $0 + 1) }
                
                var normalSum = simd_float3.zero
                
                if indexPairs.count >= 2 {
                    let lines = indexPairs.map{ normalize(points3D[$0.1] - points3D[$0.0]) }
                    
                    for i in 0..<indexPairs.count - 1 {
                        let line1 = lines[i]
                        
                        for line2 in lines[i + 1..<indexPairs.count] {
                            if dot(line1, line2) < 0.95 {
                                normalSum += cross(line1, line2)
                            }
                        }
                    }
                }
                
                if normalSum != .zero {
                    var totalWeight = UInt8(0)
                    var sampleSum = simd_float3.zero
                    
                    for globalIndex in out.globalVisibleIndices {
                        let relativeIndex = UInt8(globalIndex - fingerIndexOffset)
                        
                        if any(relativeIndex .== simd_uchar2(1, 2)) {
                            totalWeight += 2
                            
                            let jointPosition = points3D[globalIndex]
                            sampleSum = fma(jointPosition, 2, sampleSum)
                        } else {
                            totalWeight += 1
                            
                            sampleSum += points3D[globalIndex]
                        }
                    }
                    
                    if totalWeight <= 2 {
                        if totalWeight == 2 {
                            sampleSum *= 1.0 / 2
                        }
                    } else {
                        if totalWeight <= 4 {
                            if totalWeight == 3 {
                                sampleSum *= 1.0 / 3
                            } else {
                                sampleSum *= 1.0 / 4
                            }
                        } else {
                            if totalWeight == 5 {
                                sampleSum *= 1.0 / 5
                            } else {
                                sampleSum *= 1.0 / 6
                            }
                        }
                    }
                    
                    out.plane = (sampleSum, normalize(normalSum))
                }
            }
            
            return out
        }
    }
}

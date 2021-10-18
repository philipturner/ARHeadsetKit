//
//  Hand3DReconstructionExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/15/21.
//

import ARKit

extension HandRenderer {
    
    struct PointProjector {
        var scale: simd_float2
        var translation: simd_float2
        
        init(camera: ARCamera, imageResolution: CGSize) {
            let intrinsics = camera.intrinsics
            let pixelSizeMultiplier = Float(simd_fast_recip(Double(intrinsics[0][0])))
            
            let imageDimensions = simd_float2(Float(imageResolution.width), Float(imageResolution.height))
            scale       =  pixelSizeMultiplier * imageDimensions
            translation = -pixelSizeMultiplier * simd_make_float2(intrinsics[2])
        }
        
        func findCameraSpaceXY(visionTexCoords: simd_float2) -> simd_float2 {
            fma(visionTexCoords, scale, translation)
        }
    }
    
    func createProjectedPositions() {
        projectedPositions2D = [simd_float2](unsafeUninitializedCount: 21)
        projectedPositions3D = [simd_float3](unsafeUninitializedCount: 21)
        
        for i in 0..<21 {
            let filteredPosition = filteredPositions[i]
            let texCoords = simd_make_float2(filteredPosition)
            let cameraSpaceXY = pointProjectorDuringSample.findCameraSpaceXY(visionTexCoords: texCoords)
            
            projectedPositions2D[i] = cameraSpaceXY * handCenter.z
            projectedPositions3D[i] = .init(cameraSpaceXY * filteredPosition.z, -filteredPosition.z)
        }
        
        filteredPositions = nil
    }
    
    func reconstructHand(isRight: Bool) -> ReconstructedHand? {
        let points2D = projectedPositions2D!
        let points3D = projectedPositions3D!
        
        var isFront: Bool
        
        do {
            let A = fma(points2D[9] + points2D[13], 0.5, -points2D[0])
            let B = points2D[17] - points2D[5]
            
            isFront = isRight == (cross(A, B).z > 0)
        }
        
        // Find usable data
        
        var occlusionTests = testOcclusions(points2D: points2D, isFront: isFront)
        for i in 0..<21 {
            let depth = -points3D[i].z
            
            if abs(depth - handCenter.z) > 0.15 || depth > 0.8 {
                occlusionTests[i] = true
            }
        }
        
        let occlusionInfos = processOcclusionTests(points3D: points3D, occlusionTests: occlusionTests)
        
        let numDeterminedKnuckles = occlusionInfos[1..<5].filter{ $0.plane != nil || $0.visiblePoints.contains(0) }.count
        let numDeterminedPlanes   = occlusionInfos[1..<5].filter{ $0.plane != nil }.count
        
        if numDeterminedKnuckles < 2, numDeterminedPlanes == 0 {
            if !occlusionTests[0] {
                return ReconstructedHand(isRight: isRight, components: [[points3D[0]]] + Array(repeating: nil, count: 5))
            }
            
            return nil
        }
        
        // Find already determined knuckles and planes
        
        var knuckles = [simd_float3?]     (repeating: nil, count: 5)
        var planes   = [RayTracing.Plane?](repeating: nil, count: 5)
        
        for i in 0..<5 {
            let info = occlusionInfos[i]
            let fingerIndexOffset = i << 2 + 1
            
            if let plane = info.plane {
                planes[i] = plane
                
                if !info.visiblePoints.contains(0) {
                    let direction = points3D[fingerIndexOffset]
                    knuckles[i] = RayTracing.project(direction, onto: plane)
                }
            }
            
            if info.visiblePoints.contains(0) {
                knuckles[i] = points3D[fingerIndexOffset]
            }
        }
        
        // Find wrist and thumb joint positions
        
        let wrist: HandComponent? = occlusionTests[0] ? nil : [points3D[0]]
        var thumb: HandComponent?
        
        if let thumbKnuckle = knuckles[0] {
            let thumbInfo = occlusionInfos[0]
            
            if let thumbPlane = planes[0] {
                thumb = [thumbKnuckle] + Array(repeating: simd_make_float3_undef(0), count: 3)
                
                for visiblePoint in thumbInfo.visiblePoints {
                    if visiblePoint != 0 {
                        thumb![visiblePoint] = points3D[visiblePoint + 1]
                    }
                }
                
                for occludedPoint in thumbInfo.occludedPoints {
                    if occludedPoint != 0 {
                        let direction = points3D[occludedPoint + 1]
                        thumb![occludedPoint] = RayTracing.project(direction, onto: thumbPlane)
                    }
                }
            } else {
                if thumbInfo.occludedPoints.isEmpty {
                    thumb = thumbInfo.globalVisibleIndices.map{ points3D[$0] }
                }
            }
        }
        
        // Find finger joint positions
        
        var directionsAreReliable = false
        var palmTangent: simd_float3!
        var upDirection: simd_float3!
        
        func getFingerVertices(fingerID: Int) -> HandComponent? {
            let fingerInfo = occlusionInfos[fingerID]
            
            if let fingerPlane = planes[fingerID] {
                var joints = [simd_float3?](repeating: nil, count: 4)
                let fingerIndexOffset = fingerID << 2 + 1
                
                let knuckle = knuckles[fingerID]
                
                let knuckleIsDetermined = knuckle != nil
                if knuckleIsDetermined {
                    joints[0] = knuckle
                }
                
                for jointID in fingerInfo.visiblePoints {
                    if jointID == 0, knuckleIsDetermined { continue }

                    joints[jointID] = points3D[fingerIndexOffset + jointID]
                }
                
                for jointID in fingerInfo.occludedPoints {
                    if jointID == 0, knuckleIsDetermined { continue }
                    
                    let direction = points3D[fingerIndexOffset + jointID]
                    joints[jointID] = RayTracing.project(direction, onto: fingerPlane)
                }
                
                return joints.contains(nil) ? nil : joints.map{ $0! }
                
            } else if fingerInfo.occludedPoints.isEmpty {
                return fingerInfo.globalVisibleIndices.map{ points3D[$0] }
            } else {
                return nil
            }
        }
        
        func getReturnValue() -> ReconstructedHand {
            let fingers = (1..<5).map{ getFingerVertices(fingerID: $0) }
            var output = ReconstructedHand(isRight: isRight, components: [wrist, thumb] + fingers)
            
            output.directionsAreReliable = directionsAreReliable
            output.palmTangent = palmTangent
            output.upDirection = upDirection
            
            if !occlusionTests[1] { output.thumbKnuckle = points3D[1] }
            if !occlusionTests[2] { output.thumbJoint1  = points3D[2] }
            
            output.checkPointDepths(centerDepth: handCenter.z)
            return output
        }
        
        guard let wristPosition = wrist?[0] else {
            return getReturnValue()
        }
        
        let handModelFitter: HandModelFitter = isRight ? rightHandModelFitter : leftHandModelFitter
        let wristConnection_1 = handModelFitter.averageLengths.getWristConnection(fingerID: 1)
        
        for i in 1..<5 {
            guard let knucklePosition = knuckles[i] else { continue }
            
            let knuckleDelta = knucklePosition - wristPosition
            let deltaLength_squared = length_squared(knuckleDelta)
            
            let wristConnection_i = (i == 1) ? wristConnection_1
                                             : handModelFitter.averageLengths.getWristConnection(fingerID: i)
            
            let comparisons = fma(wristConnection_i, -.init(0.40 * 0.40, 1.95 * 1.95), deltaLength_squared)
            
            if comparisons[0] < 0 || comparisons[1] >= 0 {
                planes[i] = nil
                
                if occlusionInfos[i].visiblePoints.first! != 0 {
                    knuckles[i] = nil
                }
            }
        }
        
        let tempKnucklePositions = knuckles[1..<5].compactMap{ $0 }
        if tempKnucklePositions.count == 0 {
            return getReturnValue()
        }
        
        // Find palm plane
        
        var palmPlane: RayTracing.Plane!
        
        if tempKnucklePositions.count == 1 {
            let index = knuckles[1..<5].firstIndex(where: { $0 != nil })!
            
            guard let fingerPlane = planes[index] else {
                return getReturnValue()
            }
            
            palmTangent = fingerPlane.normal
            
            let knucklePosition = knuckles[index]!
            let knuckleDelta = knucklePosition - wristPosition
            
            if index == 2 {
                upDirection = normalize(knuckleDelta)
            } else if index == 1 {
                if let thumbKnuckle = knuckles[0] {
                    upDirection = normalize(knucklePosition - thumbKnuckle)
                }
            }
            
            if let upDirection = upDirection {
                let parallelComponent = project(palmTangent, upDirection)
                palmTangent = normalize(palmTangent - parallelComponent)
            }
            
            let normal = normalize(cross(upDirection ?? knuckleDelta, fingerPlane.normal))
            palmPlane = (point: wristPosition, normal: normal)
        } else {
            if let middleKnuckle = knuckles[2] {
                upDirection = normalize(middleKnuckle - wristPosition)
                
                if knuckles[1] != nil {
                    let depth = handCenter.z
                    let scale = pointProjectorDuringSample.scale * depth
                    
                    let thumbOcclusionPoints = [
                        rawPositions[2] * scale,
                        rawPositions[3] * scale,
                        rawPositions[4] * scale
                    ]
                    
                    let indexKnuckleOcclusionPoint  = rawPositions[5] * scale
                    let middleKnuckleOcclusionPoint = rawPositions[9] * scale
                    
                    if !thumbOcclusionPoints.contains(where: {
                        distance_squared($0, indexKnuckleOcclusionPoint)  < 0.02 * 0.02 ||
                        distance_squared($0, middleKnuckleOcclusionPoint) < 0.02 * 0.02
                    }) {
                        directionsAreReliable = true
                    }
                }
            } else if let indexKnuckle = knuckles[1] {
                
                if let ringKnuckle = knuckles[3] {
                    let knuckleSum = indexKnuckle + ringKnuckle
                    upDirection = normalize(fma(wristPosition, -2, knuckleSum))
                    
                } else if let littleKnuckle = knuckles[4] {
                    let knuckleSum =        fma(littleKnuckle,  0.5, indexKnuckle)
                    upDirection = normalize(fma(wristPosition, -1.5, knuckleSum))

                } else if let thumbKnuckle = knuckles[0] {
                    upDirection = normalize(indexKnuckle - thumbKnuckle)
                }
            }
            
            palmTangent = tempKnucklePositions[0] - tempKnucklePositions[1]
            
            if let upDirection = upDirection {
                palmTangent = fma(-dot(palmTangent, upDirection), upDirection, palmTangent)
            }
            
            palmTangent = normalize(palmTangent)
            
            let numKnuckles = tempKnucklePositions.count
            let numKnucklesReciprocal: Float = (numKnuckles == 2) ? 0.5
                                             : (numKnuckles == 3) ? 1.0 / 3 : 0.25
            
            let point = tempKnucklePositions.reduce(.zero, +) * numKnucklesReciprocal
            let normal = normalize(cross(upDirection ?? point - wristPosition, palmTangent))
            palmPlane = (point: point, normal: normal)
        }
        
        // Find missing knuckles and planes
        
        for i in 1..<5 {
            if knuckles[i] == nil {
                let direction = points3D[i << 2 + 1]
                knuckles[i] = RayTracing.project(direction, onto: palmPlane)
            }
            
            if planes[i] == nil {
                planes[i] = (point: knuckles[i]!, normal: palmTangent)
            }
        }
        
        return getReturnValue()
    }
    
}

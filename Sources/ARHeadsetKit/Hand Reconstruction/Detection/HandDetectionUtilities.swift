//
//  HandDetectionUtilities.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/14/21.
//

import Vision

extension VNPoint {
    var vector: simd_float2 {
        simd_float2(Float(x), Float(y))
    }
}

extension VNDetectHumanHandPoseRequest {
    
    var observations: [[simd_float2]]! {
        guard let results = results else {
            return nil
        }
        
        return results.map {
            let wrist     = try! $0.recognizedPoint(.wrist)
            
            let thumbCMC  = try! $0.recognizedPoint(.thumbCMC)
            let thumbMP   = try! $0.recognizedPoint(.thumbMP )
            let thumbIP   = try! $0.recognizedPoint(.thumbIP )
            let thumbTip  = try! $0.recognizedPoint(.thumbTip)
            
            let indexMCP  = try! $0.recognizedPoint(.indexMCP)
            let indexPIP  = try! $0.recognizedPoint(.indexPIP)
            let indexDIP  = try! $0.recognizedPoint(.indexDIP)
            let indexTip  = try! $0.recognizedPoint(.indexTip)
            
            let middleMCP = try! $0.recognizedPoint(.middleMCP)
            let middlePIP = try! $0.recognizedPoint(.middlePIP)
            let middleDIP = try! $0.recognizedPoint(.middleDIP)
            let middleTip = try! $0.recognizedPoint(.middleTip)
            
            let ringMCP   = try! $0.recognizedPoint(.ringMCP)
            let ringPIP   = try! $0.recognizedPoint(.ringPIP)
            let ringDIP   = try! $0.recognizedPoint(.ringDIP)
            let ringTip   = try! $0.recognizedPoint(.ringTip)
            
            let littleMCP = try! $0.recognizedPoint(.littleMCP)
            let littlePIP = try! $0.recognizedPoint(.littlePIP)
            let littleDIP = try! $0.recognizedPoint(.littleDIP)
            let littleTip = try! $0.recognizedPoint(.littleTip)
            
            let thumbPoints  = [ thumbCMC,   thumbMP,   thumbIP,  thumbTip]
            let indexPoints  = [ indexMCP,  indexPIP,  indexDIP,  indexTip]
            let middlePoints = [middleMCP, middlePIP, middleDIP, middleTip]
            let ringPoints   = [  ringMCP,   ringPIP,   ringDIP,   ringTip]
            let littlePoints = [littleMCP, littlePIP, littleDIP, littleTip]
            
            let fingerPointsArray = [thumbPoints, indexPoints, middlePoints, ringPoints, littlePoints]
            return fingerPointsArray.reduce([wrist.vector]){ $0 + $1.map{ $0.vector } }
        }
    }
    
}

func getFlatness(_ points: [simd_float2]) -> Float {
    if points.count <= 2 {
        return 1
    }
    
    let center = points.reduce(.zero, +) / Float(points.count)
    
    var maxIndex = -1
    var maxDistance_squared = Float(0)
    
    for i in 0..<points.count {
        let currentDistance_squared = distance_squared(center, points[i])
        
        if currentDistance_squared >= maxDistance_squared {
            maxDistance_squared = currentDistance_squared
            maxIndex = i
        }
    }
    
    var firstDelta = points[maxIndex] - center
    
    var secondMaxIndex = -1
    var secondMaxDistance_squared = Float(0)
    
    for i in 0..<points.count where i != maxIndex {
        let currentDelta = points[i] - center
        
        if dot(currentDelta, firstDelta) > 0 {
            continue
        }
        
        let currentDistance_squared = length_squared(currentDelta)
        
        if currentDistance_squared >= secondMaxDistance_squared {
            secondMaxDistance_squared = currentDistance_squared
            secondMaxIndex = i
        }
    }
    
    var secondDelta = points[secondMaxIndex] - center
    
    let deltas_lengthSquared = dotAdd(firstDelta, firstDelta,
                                     secondDelta, secondDelta)
    
    let deltas_inverseLength = simd_fast_rsqrt(deltas_lengthSquared)
    
    firstDelta  *= deltas_inverseLength[0]
    secondDelta *= deltas_inverseLength[1]
    
    if dot(firstDelta, secondDelta) > -0.5 {
        return 0
    }
    
    let longDirection = normalize(firstDelta - secondDelta)
    
    var maxPerpendicularDistance_squared = Float(0)
    
    for point in points {
        let currentDelta = point - center
        let perpendicularComponent = fma(-dot(currentDelta, longDirection), longDirection, currentDelta)
        
        maxPerpendicularDistance_squared = max(length_squared(perpendicularComponent),
                                               maxPerpendicularDistance_squared)
    }
    
    let lengthRatio = sqrt(maxPerpendicularDistance_squared / maxDistance_squared)
    
    return simd_clamp(1 - lengthRatio, 0, 1)
}

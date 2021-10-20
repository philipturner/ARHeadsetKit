//
//  SceneSorterExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import simd

extension SceneSorter {
    
    func executeSceneSort() {
        firstSceneSorter.executeFirstSort()
        
        while secondSceneSorter.smallSectorSize > 2 {
            secondSceneSorter.executeSecondSort()
        }
        
        thirdSceneSorter.executeThirdSort()
        fourthSceneSorter.executeFourthSort()
    }
    
    func makeSectorBoundary(center: simd_float3, size: Float, lineWidth: Float) -> [ARObject] {
        let trueLineWidth = lineWidth * 0.5
        let deltaWidth = trueLineWidth * 0.5
        
        let cornerData: [(simd_float3, simd_float3, simd_float3)] = [
            ([   0,    0,    0], [size,    0,    0], [          0,  deltaWidth,  deltaWidth]),
            ([   0,    0,    0], [   0,    0, size], [ deltaWidth,  deltaWidth,           0]),
            ([size,    0,    0], [size,    0, size], [-deltaWidth,  deltaWidth,           0]),
            ([   0,    0, size], [size,    0, size], [          0,  deltaWidth, -deltaWidth]),
            
            ([   0,    0,    0], [   0, size,    0], [ deltaWidth,           0,  deltaWidth]),
            ([size,    0,    0], [size, size,    0], [-deltaWidth,           0,  deltaWidth]),
            ([   0,    0, size], [   0, size, size], [ deltaWidth,           0, -deltaWidth]),
            ([size,    0, size], [size, size, size], [-deltaWidth,           0, -deltaWidth]),
            
            ([   0, size,    0], [size, size,    0], [          0, -deltaWidth,  deltaWidth]),
            ([   0, size,    0], [   0, size, size], [ deltaWidth, -deltaWidth,           0]),
            ([size, size,    0], [size, size, size], [-deltaWidth, -deltaWidth,           0]),
            ([   0, size, size], [size, size, size], [          0, -deltaWidth, -deltaWidth]),
        ]
        
        let baseCorner = simd_float3(
            fma(size, -0.5, center.x),
            fma(size, -0.5, center.y),
            fma(size, -0.5, center.z)
        )
        
        var colorHash = unsafeBitCast(center, to: simd_uint3.self)
        colorHash %= 211572
        
        let color = simd_float3(colorHash) * (1.0 / 211572)
        let sizeReciprocal = Float(simd_fast_recip(Double(size)))
        
        return cornerData.compactMap { (startCorner, endCorner, delta) in
            let baseStart = baseCorner + delta
            
            let modelSpaceBottom = baseStart + startCorner
            let modelSpaceTop    = baseStart + endCorner
            
            let orientation = simd_quatf(from: [0, 1, 0], to: (modelSpaceTop - modelSpaceBottom) * sizeReciprocal)
            
            return ARObject(shapeType: .cube,
                            position: (modelSpaceBottom + modelSpaceTop) * 0.5,
                            orientation: orientation,
                            scale: .init(trueLineWidth, size, trueLineWidth),
                            
                            color: color,
                            shininess: 12)
        }
    }
    
}
#endif

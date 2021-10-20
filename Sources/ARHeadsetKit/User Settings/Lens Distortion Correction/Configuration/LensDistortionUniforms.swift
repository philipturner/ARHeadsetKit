//
//  LensDistortionUniforms.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/10/21.
//

#if !os(macOS)
import Metal
import simd

extension LensDistortionCorrector {
    
    struct LensDistortionUniforms {
        var leftViewportOrigin: simd_ushort2
        var rightViewportOriginX: UInt16
        var framebufferMiddle: UInt16
        
        var viewportEndY_minus1: UInt16
        var leftViewportEndX: UInt16
        var rightViewportEndX: UInt16
        var optionalLastDispatchY: UInt16
        
        var clipOffset: Float16
        var maxRadiusSquared: Float
        var maxRadiusSquaredInverse: Float
        
        var k1_coefficients: simd_packed_half3
        var k2_coefficients: simd_packed_half3
        
        var compressionRatio: Float16
        var intermediateSideLengthHalf: Float
        var clearingFramebuffer: Bool
        
        var showingRedBlueColor: simd_bool2
        
        init(corrector: LensDistortionCorrector, clearingFramebuffer: Bool) {
            framebufferMiddle = UInt16(corrector.screenDimensions.x >> 1)
            
            let viewSideLength = UInt16(corrector.viewSideLength)
            let viewSideLengthHalf = viewSideLength >> 1
            var originBase = simd_ushort2(truncatingIfNeeded: corrector.screenDimensions) &>> [1, 0]
            originBase &-= viewSideLengthHalf
            
            leftViewportOrigin = originBase &- simd_ushort2(
                .init(corrector.viewCenterToMiddleDistance),
                .init(corrector.viewCenterToBottomDistance)
            )
            
            rightViewportOriginX = originBase.x &+ UInt16(corrector.viewCenterToMiddleDistance)
            
            let viewSideLength_minus1 = viewSideLength - 1
            viewportEndY_minus1 = leftViewportOrigin.y &+ viewSideLength_minus1
            leftViewportEndX    = leftViewportOrigin.x &+ viewSideLength_minus1
            rightViewportEndX   = rightViewportOriginX &+ viewSideLength_minus1
            
            if corrector.screenDimensions.y & 1 == 0 {
                optionalLastDispatchY = .max
            } else {
                optionalLastDispatchY = .init(corrector.screenDimensions.y >> 1)
            }
            
            let viewSideLengthHalf_float = Float(viewSideLengthHalf)
            clipOffset = .init(0.5 - viewSideLengthHalf_float)
            maxRadiusSquared = viewSideLengthHalf_float * viewSideLengthHalf_float
            maxRadiusSquaredInverse = .init(simd_fast_recip(Double(maxRadiusSquared)))
            
            
            
            let compressionRatio = corrector.intermediateResolutionCompressionRatio!
            
            @inline(__always)
            func getCoefficients(_ green: Float, _ proportions: simd_float2) -> simd_packed_half3 {
                let multipliers = simd_float3(proportions[0] * compressionRatio,
                                                               compressionRatio,
                                              proportions[1] * compressionRatio)
                
                return simd_packed_half3(green * multipliers)
            }
            
            var storedSettings: LensDistortionCorrector.StoredSettings { corrector.storedSettings }
            
            k1_coefficients = getCoefficients(storedSettings.k1_green, storedSettings.k1_proportions)
            k2_coefficients = getCoefficients(storedSettings.k2_green, storedSettings.k2_proportions)
            
            self.compressionRatio = .init(compressionRatio)
            intermediateSideLengthHalf = Float(corrector.intermediateSideLength) * (compressionRatio * 0.5)
            
            self.clearingFramebuffer = clearingFramebuffer
            showingRedBlueColor = .init(corrector.showingRedColor, corrector.showingBlueColor)
        }
    }
    
}
#endif

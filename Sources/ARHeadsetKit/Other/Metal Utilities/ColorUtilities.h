//
//  ColorUtilities.h
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/24/21.
//

#ifndef ColorUtilities_h
#define ColorUtilities_h

#include <metal_stdlib>
using namespace metal;

namespace ColorUtilities {
    half3 convertYCbCr_toRGB(half2 chroma, half luma);
    
    /**
     An optimized Blinn-Phong shading function that utilizes half-precision arithmetic, opts out of expensive pow() operations whenever possible, and correctly calculates normals.
     */
    half3 getLightContribution(half3 lightDirection,
                               half3 directionalLightColor,
                               half3 ambientLightColor,
                               
                               half  shininess,
                               half  normal_lengthSquared,
                               half3 normal_notNormalized,
                               half  eyeDirection_lengthSquared,
                               half3 eyeDirection_notNormalized);
    
    bool attemptAtomicallyAddHalf(half2 lhs, device atomic_uint *rhs);
}

namespace SceneColorReconstruction {
    struct Texel {
        uchar4 luma;
        uchar2 chroma;
        
        half4 unpackLuma()   { return half4(luma)   * half4(1.0 / 255); }
        half2 unpackChroma() { return half2(chroma) * half2(1.0 / 255); }
        
        void packLuma  (half4 luma)   { this->luma   = uchar4(rint(luma * 255)); }
        void packChroma(half2 chroma) { this->chroma = uchar2(rint(chroma * 255)); }
    };
    
    class YCbCrTexture {
        device uchar2 *lumaRows;
        device uchar2 *chromaRows;
        
    public:
        YCbCrTexture(device uchar2 *lumaRows, device uchar2 *chromaRows)
        {
            this->lumaRows   = lumaRows;
            this->chromaRows = chromaRows;
        }
        
        Texel read(ushort2 texCoords) const;
        
        void write(Texel input, ushort2 texCoords);
        
        void createPadding(Texel input, ushort2 texCoords,
                           ushort lastHeight, ushort currentHeight, ushort nextHeight,
                           ushort offsetY, thread ushort &nextOffsetY);
    };
}

#endif /* ColorUtilities_h */

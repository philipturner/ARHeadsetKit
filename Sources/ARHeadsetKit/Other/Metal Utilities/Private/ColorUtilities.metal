//
//  ColorUtilities.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/24/21.
//

#include <metal_stdlib>
#include "../ColorUtilities.h"
using namespace metal;

half3 ColorUtilities::convertYCbCr_toRGB(half2 chroma, half luma)
{
    half3 out;
    
    out.rg = fma(half2(1.4020, -0.7141), chroma.g, half2(-0.7017, 0.5291));
    out.b = luma - 0.8860;
    
    out.gb = fma(half2(-0.3441, 1.7720), chroma.r, out.gb);
    out.rg += half2(luma);
    
    return out;
}

half3 ColorUtilities::getLightContribution(half3 lightDirection,
                                           half3 directionalLightColor,
                                           half3 ambientLightColor,
                                           half  shininess,
                                           
                                           half  normal_lengthSquared,
                                           half3 normal_notNormalized,
                                           half  eyeDirection_lengthSquared,
                                           half3 eyeDirection_notNormalized)
{
    half eyeDirectionMultiplier = rsqrt(eyeDirection_lengthSquared);
    half normalMultiplier       = rsqrt(normal_lengthSquared);
    
    half3 halfwayVector_notNormalized = fma(eyeDirection_notNormalized, eyeDirectionMultiplier, lightDirection);
    half directionalLightContribution = dot(normal_notNormalized,                               lightDirection);
    
    half halfwayVectorMultiplier = length_squared(halfwayVector_notNormalized);
    half reflectionAngleCosine   = dot(normal_notNormalized, halfwayVector_notNormalized);
    
    directionalLightContribution = saturate(directionalLightContribution * normalMultiplier);
    reflectionAngleCosine *= normalMultiplier;
    
    if (reflectionAngleCosine > (1 / 256.0) * halfwayVectorMultiplier && halfwayVectorMultiplier >= HALF_MIN)
    {
        reflectionAngleCosine *= fast::rsqrt(float(halfwayVectorMultiplier));
        directionalLightContribution += fast::powr(float(reflectionAngleCosine), float(shininess));
    }
    
    if (directionalLightContribution > 0)
    {
        return fma(directionalLightColor, directionalLightContribution, ambientLightColor);
    }
    else
    {
        return ambientLightColor;
    }
}



namespace InternalColorUtilities {
    template <typename T, T modify(T lhs, T rhs)>
    bool attemptAtomicallyModify(T lhs, device atomic_uint *rhs)
    {
        uint old_rhs;
        old_rhs = atomic_load_explicit(rhs, memory_order_relaxed);
        
        uint new_rhs = as_type<uint>(modify(lhs, as_type<T>(old_rhs)));
        
        return atomic_compare_exchange_weak_explicit(rhs, &old_rhs, new_rhs,
                                                     memory_order_relaxed, memory_order_relaxed);
    }

    template <typename T, T modify(T lhs, T rhs)>
    bool attemptAtomicallyModify(device atomic_uint *lhs, T rhs)
    {
        uint old_lhs;
        old_lhs = atomic_load_explicit(lhs, memory_order_relaxed);
        
        uint new_lhs = as_type<uint>(modify(as_type<T>(old_lhs), rhs));
        
        return atomic_compare_exchange_weak_explicit(lhs, &old_lhs, new_lhs,
                                                     memory_order_relaxed, memory_order_relaxed);
    }

    template <typename T, T modify(T lhs, T mid, T rhs)>
    bool attemptAtomicallyModify(T lhs, device atomic_uint *mid, T rhs)
    {
        uint old_mid;
        old_mid = atomic_load_explicit(mid, memory_order_relaxed);
        
        uint new_mid = as_type<uint>(modify(as_type<T>(old_mid), mid));
        
        return atomic_compare_exchange_weak_explicit(mid, &old_mid, new_mid,
                                                     memory_order_relaxed, memory_order_relaxed);
    }
    
    template<typename T> T add       (T lhs, T rhs) { return lhs + rhs; }
    template<typename T> T subtract  (T lhs, T rhs) { return lhs - rhs; }
    template<typename T> T multiply  (T lhs, T rhs) { return lhs * rhs; }
    template<typename T> T fma(T lhs, T mid, T rhs) { return fma(lhs, mid, rhs); }
}

using namespace InternalColorUtilities;

bool ColorUtilities::attemptAtomicallyAddHalf(half2 lhs, device atomic_uint *rhs)
{
    return attemptAtomicallyModify<half2, add>(lhs, rhs);
}



using namespace SceneColorReconstruction;

Texel YCbCrTexture::read(ushort2 texCoords) const
{
    uint chromaRowOffset = uint(texCoords.y) << 13;
    uint chromaIndex = chromaRowOffset + texCoords.x;
    uchar2 sampleChroma = chromaRows[chromaIndex];
    
    uint lumaIndex = chromaIndex + chromaRowOffset;
    uchar4 sampleLuma(lumaRows[lumaIndex], lumaRows[lumaIndex + 8192]);
    
    return { sampleLuma, sampleChroma };
}

void YCbCrTexture::write(Texel input, ushort2 texCoords)
{
    uint chromaRowOffset = uint(texCoords.y) << 13;
    uint chromaIndex = chromaRowOffset + texCoords.x;
    chromaRows[chromaIndex] = input.chroma;
    
    uint lumaIndex = chromaIndex + chromaRowOffset;
    lumaRows[lumaIndex]        = input.luma.xy;
    lumaRows[lumaIndex + 8192] = input.luma.zw;
}

void YCbCrTexture::createPadding(Texel input, ushort2 texCoords,
                                 ushort lastHeight, ushort currentHeight, ushort nextHeight,
                                 ushort offsetY, thread ushort &nextOffsetY)
{
#define TRANSFER_TEXEL_DATA(components, offsetX, offsetY)                               \
write({ input.luma.components, input.chroma }, texCoords + ushort2(offsetX, offsetY));  \
// forced space for concatenating files
    if (offsetY == 0)
    {
        TRANSFER_TEXEL_DATA(xyxy, 0, -1);
        
        if (lastHeight == 0) { TRANSFER_TEXEL_DATA(xxxx, -1, -1); }
        if (nextHeight == 0) { TRANSFER_TEXEL_DATA(yyyy,  1, -1); }
    }
    
    if (offsetY > lastHeight || lastHeight == 0) { TRANSFER_TEXEL_DATA(xxzz, -1, 0); }
    if (offsetY > nextHeight || nextHeight == 0) { TRANSFER_TEXEL_DATA(yyww,  1, 0); }
    
    nextOffsetY = offsetY + 1;
    
    if (nextOffsetY == currentHeight)
    {
        TRANSFER_TEXEL_DATA(zwzw, 0, 1);
        
        if (nextOffsetY > lastHeight || lastHeight == 0) { TRANSFER_TEXEL_DATA(zzzz, -1, 1); }
        if (nextOffsetY > nextHeight || nextHeight == 0) { TRANSFER_TEXEL_DATA(wwww,  1, 1); }
    }
}

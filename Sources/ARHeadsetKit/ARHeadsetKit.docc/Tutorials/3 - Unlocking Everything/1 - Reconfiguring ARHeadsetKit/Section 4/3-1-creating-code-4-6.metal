#include <metal_stdlib>
#include <ARHeadsetKit/ColorUtilities.h>
using namespace metal;

half3 foo(half2 chroma, half luma)
{
    return ColorUtilities::convertYCbCr_toRGB(chroma, luma);
}

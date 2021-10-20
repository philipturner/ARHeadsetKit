//
//  SceneRendering.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

#define VertexInOut_Common                  \
float4  position [[position]];              \
float2  videoFrameCoords;                   \
                                            \
uint    triangleID;                         \
ushort2 baseTextureOffset;                  \
                                            \
half2   texCoords [[centroid_perspective]]; \

typedef struct {
    VertexInOut_Common;
} VertexInOut;

typedef struct {
    VertexInOut_Common;
    ushort layer [[render_target_array_index]];
} VRVertexInOut;



#define SCENE_VERTEX_TRANSFORM_PARAMS                           \
const device float4  *vertices                [[ buffer(0) ]],  \
const device float2  *videoFrameCoords        [[ buffer(1) ]],  \
const device uint    *renderOffsets           [[ buffer(2) ]],  \
                                                                \
const device uint    *triangleIDs             [[ buffer(3) ]],  \
const device uint3   *reducedIndices          [[ buffer(4) ]],  \
                                                                \
const device ushort2 *textureOffsets          [[ buffer(5) ]],  \
const device float4  *rasterizationComponents [[ buffer(6) ]],  \
                                                                \
uint   iid [[ instance_id ]],                                   \
ushort vid [[ vertex_id ]]                                      \

template <typename VertexInOut>
VertexInOut sceneVertexTransformCommon(SCENE_VERTEX_TRANSFORM_PARAMS, ushort amp_count,
                                       ushort amp_id, float positionDelta)
{
    uint triangleID = triangleIDs[iid];
    bool isVisibleToCamera = as_type<ushort2>(triangleID)[1] & 0x8000;
    reinterpret_cast<thread ushort2&>(triangleID)[1] &= ~(0x8000);
    
    VertexInOut out;
    
    out.triangleID = isVisibleToCamera ? __UINT32_MAX__ : triangleID;
    out.baseTextureOffset = textureOffsets[triangleID];
    
    uint3 indices = reducedIndices[triangleID];
    uint vertexOffset = renderOffsets[indices[vid]];
    
    out.videoFrameCoords = videoFrameCoords[vertexOffset];
    out.position = vertices[vertexOffset];
    
    if (amp_count == 2 && amp_id == 1)
    {
        out.position.x += positionDelta;
    }
    
    
    
    float4 components = rasterizationComponents[triangleID];
    ushort withinTriangleIndex = vid + as_type<uchar4>(components[3])[1];
    if (withinTriangleIndex > 3) { withinTriangleIndex -= 3; }
    
    out.texCoords = select(0, half2(components.yz), withinTriangleIndex == 2);
    if (withinTriangleIndex == 1) { out.texCoords.x = components.x; }
    
    return out;
}

#define CALL_SCENE_VERTEX_TRANSFORM_COMMON(VertexInOut, amp_count, amp_id, positionDelta)           \
sceneVertexTransformCommon<VertexInOut>(vertices, videoFrameCoords, renderOffsets, triangleIDs,     \
                                        reducedIndices, textureOffsets, rasterizationComponents,    \
                                        iid, vid, amp_count, amp_id, positionDelta);                \



vertex VertexInOut sceneVertexTransform(SCENE_VERTEX_TRANSFORM_PARAMS)
{
    return CALL_SCENE_VERTEX_TRANSFORM_COMMON(VertexInOut, 1, 0, NAN);
}

vertex VRVertexInOut sceneVRVertexTransform(SCENE_VERTEX_TRANSFORM_PARAMS,
                                            constant float &positionDelta [[ buffer(29) ]],
                                            
                                            ushort amp_id [[ amplification_id ]])
{
    auto out = CALL_SCENE_VERTEX_TRANSFORM_COMMON(VRVertexInOut, 2, amp_id, positionDelta);
    out.layer = amp_id;
    
    return out;
}

vertex VertexInOut sceneVRVertexTransform2(SCENE_VERTEX_TRANSFORM_PARAMS,
                                           constant float  &positionDelta [[ buffer(29) ]],
                                           constant ushort &amp_id        [[ buffer(30) ]])
{
    return CALL_SCENE_VERTEX_TRANSFORM_COMMON(VertexInOut, 2, amp_id, positionDelta);
}



#define SCENE_FRAGMENT_SHADER_PARAMS                                            \
texture2d<uint, access::sample> idTexture                  [[ texture(0) ]],    \
texture2d<half, access::sample> colorTextureY              [[ texture(1) ]],    \
texture2d<half, access::sample> colorTextureCbCr           [[ texture(2) ]],    \
                                                                                \
texture2d<half, access::sample> smallTriangleLumaTexture   [[ texture(3) ]],    \
texture2d<half, access::sample> largeTriangleLumaTexture   [[ texture(4) ]],    \
texture2d<half, access::sample> smallTriangleChromaTexture [[ texture(5) ]],    \
texture2d<half, access::sample> largeTriangleChromaTexture [[ texture(6) ]]     \

half3 sceneFragmentShaderCommon(VertexInOut in, bool checkingY, SCENE_FRAGMENT_SHADER_PARAMS)
{
    half2 chroma;
    half  luma;
    
    constexpr sampler idSampler(filter::nearest);
    
    if (in.triangleID != __UINT32_MAX__ &&
        
        saturate(in.videoFrameCoords.x) == in.videoFrameCoords.x &&
        (!checkingY || saturate(in.videoFrameCoords.y) == in.videoFrameCoords.y) &&

        any(idTexture.gather(idSampler, in.videoFrameCoords) == in.triangleID))
    {
        constexpr sampler colorSampler(filter::linear);
        
        chroma = colorTextureCbCr.sample(colorSampler, in.videoFrameCoords).rg;
        luma   = colorTextureY   .sample(colorSampler, in.videoFrameCoords).r;
    }
    else
    {
        constexpr sampler chromaSampler(coord::pixel, filter::linear);
        constexpr sampler lumaSampler  (coord::pixel, filter::bicubic);
        
        float2 chromaCoords = float2(in.baseTextureOffset & ushort2(0xFFFF, 0x7FFF)) + float2(in.texCoords);
        float2 lumaCoords   = chromaCoords + chromaCoords;
        
        if (in.baseTextureOffset.y & 0x8000)
        {
            chroma = largeTriangleChromaTexture.sample(chromaSampler, chromaCoords).rg;
            luma   = largeTriangleLumaTexture  .sample(lumaSampler,   lumaCoords).r;
        }
        else
        {
            chroma = smallTriangleChromaTexture.sample(chromaSampler, chromaCoords).rg;
            luma   = smallTriangleLumaTexture  .sample(lumaSampler,   lumaCoords).r;
        }
    }

    return ColorUtilities::convertYCbCr_toRGB(chroma, luma);
}

[[early_fragment_tests]]
fragment half3 sceneFragmentShader(VertexInOut in [[ stage_in ]], SCENE_FRAGMENT_SHADER_PARAMS)
{
    return sceneFragmentShaderCommon(in, false,
                                     idTexture, colorTextureY, colorTextureCbCr,
                                     smallTriangleLumaTexture,   largeTriangleLumaTexture,
                                     smallTriangleChromaTexture, largeTriangleChromaTexture);
}

[[early_fragment_tests]]
fragment half3 sceneVRFragmentShader(VertexInOut in [[ stage_in ]], SCENE_FRAGMENT_SHADER_PARAMS)
{
    return sceneFragmentShaderCommon(in, true,
                                     idTexture, colorTextureY, colorTextureCbCr,
                                     smallTriangleLumaTexture,   largeTriangleLumaTexture,
                                     smallTriangleChromaTexture, largeTriangleChromaTexture);
}
#endif

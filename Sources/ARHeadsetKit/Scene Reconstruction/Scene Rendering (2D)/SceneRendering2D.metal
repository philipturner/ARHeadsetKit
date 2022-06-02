//
//  SceneRendering2D.metal.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

typedef struct {
    float2 imageBounds;
    float  cameraPlaneDepth;
    bool   usingFlyingMode;
} VertexUniforms;



#define VertexInOut_Common      \
float4 position [[position]];   \
float2 videoFrameCoords;        \

typedef struct {
    VertexInOut_Common;
} VertexInOut;

typedef struct {
    VertexInOut_Common;
    ushort layer [[render_target_array_index]];
} VRVertexInOut;



#define SCENE_2D_VERTEX_TRANSFORM_PARAMS                    \
constant float4x4 *projectionTransforms [[ buffer(0) ]],    \
constant VertexUniforms &vertexUniforms [[ buffer(1) ]],    \
                                                            \
ushort vid [[ vertex_id ]]                                  \

template <typename VertexInOut, bool usingVertexAmplification>
VertexInOut scene2DVertexTransformCommon(SCENE_2D_VERTEX_TRANSFORM_PARAMS, ushort amp_id)
{
    float3 cameraSpacePosition(vertexUniforms.imageBounds, vertexUniforms.cameraPlaneDepth);

    bool isRight = any(ushort3(1, 2, 4) == vid);
    bool isTop   = any(ushort3(2, 4, 5) == vid);
    
    if (!isRight) { cameraSpacePosition.x = -cameraSpacePosition.x; }
    if (!isTop)   { cameraSpacePosition.y = -cameraSpacePosition.y; }
    
    float2 texCoords(
        select(0, 1, isRight),
        select(1, 0, isTop)
    );
    
    float4 position = projectionTransforms[amp_id] * float4(cameraSpacePosition, 1);
    
    if (!usingVertexAmplification && !vertexUniforms.usingFlyingMode)
    {
        position.y = copysign(position.w, position.y);
    }
    
    return { position, texCoords };
}



vertex VertexInOut scene2DVertexTransform(SCENE_2D_VERTEX_TRANSFORM_PARAMS)
{
    return scene2DVertexTransformCommon<VertexInOut, false>(projectionTransforms, vertexUniforms, vid, 0);
}

vertex VRVertexInOut scene2DVRVertexTransform(SCENE_2D_VERTEX_TRANSFORM_PARAMS,
                                              ushort amp_id [[ amplification_id ]])
{
    auto out = scene2DVertexTransformCommon<VRVertexInOut, true>(projectionTransforms, vertexUniforms, vid, amp_id);
    out.layer = amp_id;
    
    return out;
}

vertex VertexInOut scene2DVRVertexTransform2(SCENE_2D_VERTEX_TRANSFORM_PARAMS,
                                             constant ushort &amp_id [[ buffer(30) ]])
{
    return scene2DVertexTransformCommon<VertexInOut, true>(projectionTransforms, vertexUniforms, vid, amp_id);
}



typedef struct {
    half3 color [[color(0)]];
    float depth [[depth(any)]];
} FragmentOut;

fragment FragmentOut scene2DFragmentShader(VertexInOut in [[ stage_in ]],
                                           
                                           texture2d<half, access::sample> colorTextureY    [[ texture(0) ]],
                                           texture2d<half, access::sample> colorTextureCbCr [[ texture(1) ]])
{
    constexpr sampler colorSampler(filter::linear);
    
    half2 chroma = colorTextureCbCr.sample(colorSampler, in.videoFrameCoords).rg;
    half  luma   = colorTextureY   .sample(colorSampler, in.videoFrameCoords).r;
    
    return { ColorUtilities::convertYCbCr_toRGB(chroma, luma), FLT_MIN };
}

fragment FragmentOut scene2DFragmentShader2(VertexInOut in [[ stage_in ]],
                                            
                                            texture2d<half, access::sample> colorTextureY       [[ texture(0) ]],
                                            texture2d<half, access::sample> colorTextureCbCr    [[ texture(1) ]],
                                            texture2d<half, access::sample> segmentationTexture [[ texture(2) ]])
{
//    constexpr sampler colorSampler(filter::linear);
//
//    half2 chroma = colorTextureCbCr.sample(colorSampler, in.videoFrameCoords).rg;
//    half  luma   = colorTextureY   .sample(colorSampler, in.videoFrameCoords).r;
//
//    return { ColorUtilities::convertYCbCr_toRGB(chroma, luma), FLT_MIN };
    
    return { half3(1, 0, 0), FLT_MIN };
}
#endif

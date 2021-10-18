//
//  InterfaceRendering.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/28/21.
//

#include <metal_stdlib>
#include "../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

typedef struct {
    float4x4 projectionTransforms[1];
    float4x3 eyeDirectionTransforms[1];
    half3x3  normalTransform;
} VertexUniforms;

typedef struct {
    float4x4 projectionTransforms[2];
    float4x3 eyeDirectionTransforms[2];
    half3x3  normalTransform;
} VRVertexUniforms;

typedef struct {
    half3 ambientLightColor;
    half3 ambientInsideLightColor;
    
    half3 directionalLightColor;
    half3 lightDirection;
} GlobalFragmentUniforms;

typedef struct {
    packed_half3 surfaceColor;
    half         surfaceShininess;
    
    half3        textColor;
    half         textShininess;
    half         textOpacity;
} FragmentUniforms;



#define DepthPassInOut_Common       \
float4 position [[position]];       \

#define SurfaceInOut_Common         \
float4 position [[position]];       \
half3  eyeDirection_notNormalized;  \
half3  normal_notNormalized;        \

#define TextInOut_Common            \
float4 position [[position]];       \
half3  eyeDirection_notNormalized;  \
half3  normal_normalized [[flat]];  \
                                    \
float2 texCoords;                   \

typedef struct {
    DepthPassInOut_Common;
} DepthPassInOut;

typedef struct {
    SurfaceInOut_Common;
} SurfaceInOut;

typedef struct {
    TextInOut_Common;
} TextInOut;

typedef struct {
    DepthPassInOut_Common;
    ushort layer [[render_target_array_index]];
} VRDepthPassInOut;

typedef struct {
    SurfaceInOut_Common;
    ushort layer [[render_target_array_index]];
} VRSurfaceInOut;

typedef struct {
    TextInOut_Common;
    ushort layer [[render_target_array_index]];
} VRTextInOut;

#define INTERFACE_DEPTH_PASS_TRANSFORM_PARAMS               \
constant     ushort2 *vertexAttributes [[ buffer(1) ]],     \
const device float4  *vertices         [[ buffer(5) ]],     \
                                                            \
uint   iid [[ instance_id ]],                               \
ushort vid [[ vertex_id ]]                                  \

#define INTERFACE_SURFACE_TRANSFORM_PARAMS                  \
constant     ushort2 *vertexAttributes [[ buffer(1) ]],     \
                                                            \
const device float4  *vertices         [[ buffer(5) ]],     \
const device float3  *eyeDirections    [[ buffer(6) ]],     \
const device half3   *normals          [[ buffer(7) ]],     \
                                                            \
ushort vid [[ vertex_id ]]                                  \

#define INTERFACE_TEXT_TRANSFORM_PARAMS(VertexUniforms)     \
constant VertexUniforms &vertexUniforms [[ buffer(0) ]],    \
constant float4         *glyphTexCoords [[ buffer(2) ]],    \
                                                            \
constant float4         *boundingRects  [[ buffer(3) ]],    \
constant ushort         *glyphIndices   [[ buffer(4) ]],    \
                                                            \
ushort iid [[ instance_id ]],                               \
ushort vid [[ vertex_id ]]                                  \



template <typename DepthPassInOut>
DepthPassInOut interfaceDepthPassTransformCommon(INTERFACE_DEPTH_PASS_TRANSFORM_PARAMS, ushort amp_count,
                                                 ushort amp_id, float positionDelta)
{
    uint meshStart = (iid << 8) + (iid << 4);
    ushort vertexIndex = meshStart + vertexAttributes[vid][0];
    
    float4 position = vertices[vertexIndex];
    
    if (amp_count == 2 && amp_id == 1)
    {
        position.x += positionDelta;
    }
    
    return { position };
}

vertex DepthPassInOut interfaceDepthPassTransform(INTERFACE_DEPTH_PASS_TRANSFORM_PARAMS)
{
    return interfaceDepthPassTransformCommon<DepthPassInOut>(vertexAttributes, vertices, iid, vid, 1,
                                                             0, NAN);
}

vertex VRDepthPassInOut interfaceVRDepthPassTransform(INTERFACE_DEPTH_PASS_TRANSFORM_PARAMS,
                                                      constant float &positionDelta [[ buffer(29) ]],
                                                      
                                                      ushort amp_id [[ amplification_id ]])
{
    auto out = interfaceDepthPassTransformCommon<VRDepthPassInOut>(vertexAttributes, vertices, iid, vid, 2,
                                                                   amp_id, positionDelta);
    out.layer = amp_id;
    
    return out;
}

vertex DepthPassInOut interfaceVRDepthPassTransform2(INTERFACE_DEPTH_PASS_TRANSFORM_PARAMS,
                                                     constant float  &positionDelta [[ buffer(29) ]],
                                                     constant ushort &amp_id        [[ buffer(30) ]])
{
    return interfaceDepthPassTransformCommon<DepthPassInOut>(vertexAttributes, vertices, iid, vid, 2,
                                                             amp_id, positionDelta);
}



template <typename SurfaceInOut>
SurfaceInOut interfaceSurfaceTransformCommon(INTERFACE_SURFACE_TRANSFORM_PARAMS, ushort amp_count,
                                             ushort amp_id, float3 eyeDirectionDelta, float positionDelta)
{
    ushort2 retrievedAttributes = vertexAttributes[vid];
    
    if (amp_count == 2)
    {
        float4 position     = vertices     [retrievedAttributes[0]];
        float3 eyeDirection = eyeDirections[retrievedAttributes[0]];
        
        if (amp_count == 2 && amp_id == 1)
        {
            position.x   += positionDelta;
            eyeDirection += eyeDirectionDelta;
        }
        
        return {
            position, half3(eyeDirection), normals[retrievedAttributes[1]]
        };
    }
    else
    {
        auto eyeDirections_alt = reinterpret_cast<const device half3*>(eyeDirections);
        
        return {
            vertices         [retrievedAttributes[0]],
            eyeDirections_alt[retrievedAttributes[0]],
            normals          [retrievedAttributes[1]]
        };
    }
}

vertex SurfaceInOut interfaceSurfaceTransform(INTERFACE_SURFACE_TRANSFORM_PARAMS)
{
    return interfaceSurfaceTransformCommon<SurfaceInOut>(vertexAttributes, vertices, eyeDirections, normals, vid, 1,
                                                         0, float3(NAN), NAN);
}

vertex VRSurfaceInOut interfaceVRSurfaceTransform(INTERFACE_SURFACE_TRANSFORM_PARAMS,
                                                  constant float3 &eyeDirectionDelta [[ buffer(28) ]],
                                                  constant float  &positionDelta     [[ buffer(29) ]],
                                                  
                                                  ushort amp_id [[ amplification_id ]])
{
    auto out = interfaceSurfaceTransformCommon<VRSurfaceInOut>(vertexAttributes, vertices, eyeDirections, normals, vid, 2,
                                                               amp_id, eyeDirectionDelta, positionDelta);
    out.layer = amp_id;
    
    return out;
}

vertex SurfaceInOut interfaceVRSurfaceTransform2(INTERFACE_SURFACE_TRANSFORM_PARAMS,
                                                 constant float3 &eyeDirectionDelta [[ buffer(28) ]],
                                                 constant float  &positionDelta     [[ buffer(29) ]],
                                                 constant ushort &amp_id            [[ buffer(30) ]])
{
    return interfaceSurfaceTransformCommon<SurfaceInOut>(vertexAttributes, vertices, eyeDirections, normals, vid, 2,
                                                         amp_id, eyeDirectionDelta, positionDelta);
}



template <typename TextInOut, typename VertexUniforms>
TextInOut interfaceTextTransformCommon(INTERFACE_TEXT_TRANSFORM_PARAMS(VertexUniforms), ushort amp_id,
                                       bool usingAmplification, float3 eyeDirectionDelta, float positionDelta)
{
    auto retrievedBoundingRect = boundingRects[iid];
    auto retrievedTexCoords = glyphTexCoords[glyphIndices[iid]];
    
    float2 position;
    float2 texCoords;
    
    if (any(ushort2(0, 3) == vid))
    {
        position.x  = retrievedBoundingRect[0];
        texCoords.x = retrievedTexCoords[0];
    }
    else
    {
        position.x  = retrievedBoundingRect[2];
        texCoords.x = retrievedTexCoords[2];
    }
    
    if (any(ushort2(0, 1) == vid))
    {
        position.y  = retrievedBoundingRect[1];
        texCoords.y = retrievedTexCoords[1];
    }
    else
    {
        position.y  = retrievedBoundingRect[3];
        texCoords.y = retrievedTexCoords[3];
    }
    
    
    
    float4 clipPosition;
    float3 eyeDirection;
    
    if (usingAmplification)
    {
        clipPosition = vertexUniforms.projectionTransforms[0] * float4(position, 0.5, 1);
        eyeDirection = vertexUniforms.eyeDirectionTransforms[0] * float4(position, 0.5, 1);
        
        if (amp_id == 1)
        {
            clipPosition.x += positionDelta;
            eyeDirection   += eyeDirectionDelta;
        }
    }
    else
    {
        clipPosition = vertexUniforms.projectionTransforms[amp_id] * float4(position, 0.5, 1);
        eyeDirection = vertexUniforms.eyeDirectionTransforms[amp_id] * float4(position, 0.5, 1);
    }
    
    return {
        clipPosition, half3(eyeDirection), vertexUniforms.normalTransform[2],
        texCoords
    };
}



vertex TextInOut interfaceTextTransform(INTERFACE_TEXT_TRANSFORM_PARAMS(VertexUniforms))
{
    return interfaceTextTransformCommon<TextInOut>(vertexUniforms, glyphTexCoords,
                                                   boundingRects, glyphIndices,
                                                   iid, vid, 0,
                                                   false, float3(NAN), NAN);
}

vertex VRTextInOut interfaceVRTextTransform(INTERFACE_TEXT_TRANSFORM_PARAMS(VRVertexUniforms),
                                            constant float3 &eyeDirectionDelta [[ buffer(28) ]],
                                            constant float  &positionDelta     [[ buffer(29) ]],
                                            
                                            ushort amp_id [[ amplification_id ]])
{
    auto out = interfaceTextTransformCommon<VRTextInOut>(vertexUniforms, glyphTexCoords,
                                                         boundingRects, glyphIndices,
                                                         iid, vid, amp_id,
                                                         true, eyeDirectionDelta, positionDelta);
    out.layer = amp_id;
    
    return out;
}

vertex TextInOut interfaceVRTextTransform2(INTERFACE_TEXT_TRANSFORM_PARAMS(VRVertexUniforms),
                                           constant ushort &amp_id [[ buffer(30) ]])
{
    return interfaceTextTransformCommon<TextInOut>(vertexUniforms, glyphTexCoords,
                                                   boundingRects, glyphIndices,
                                                   iid, vid, amp_id,
                                                   false, float3(NAN), NAN);
}

vertex float4 clearStencilVertexTransform(ushort vid [[ vertex_id ]])
{
    return {
        select(float(-1), float(1), any(ushort3(0, 3, 5) == vid)),
        select(float(-1), float(1), any(ushort3(0, 1, 3) == vid)),
        0, 1
    };
}



// 0.75 / sqrt(sqrt(2)) - normalize for the fact that `fwidth`
// varies by a factor of sqrt(2) depending on orientation
constant float EDGE_MULTIPLIER = 0.75 / 1.189207155;

[[early_fragment_tests]]
fragment half4 interfaceTextFragmentShader(TextInOut in [[ stage_in ]],
                                           
                                           constant GlobalFragmentUniforms &globalUniforms [[ buffer(0) ]],
                                           constant FragmentUniforms       &uniforms       [[ buffer(1) ]],
                                           
                                           texture2d<float, access::sample> signedDistanceField [[ texture(0) ]])
{
    constexpr sampler textureSampler(coord::pixel, filter::linear);
    float sampleDistance = signedDistanceField.sample(textureSampler, in.texCoords).r;
    float edgeWidth = fwidth(sampleDistance);
    
    float numerator = fma(edgeWidth, EDGE_MULTIPLIER, sampleDistance - 0.5);
    float denominator = edgeWidth * (EDGE_MULTIPLIER * 2);
    
    half t = saturate(fast::divide(numerator, denominator));
    if (t == 0) { discard_fragment(); }
    
    half alpha = (t * t) * saturate(fma(t, -2, 3));
    half eyeDirection_lengthSquared = length_squared(in.eyeDirection_notNormalized);
    
    half3 lightContribution = ColorUtilities::getLightContribution(globalUniforms.lightDirection,
                                                                   globalUniforms.directionalLightColor,
                                                                   globalUniforms.ambientLightColor,
                                                                   uniforms.textShininess,
                                                                   
                                                                   1,
                                                                   in.normal_normalized,
                                                                   eyeDirection_lengthSquared,
                                                                   in.eyeDirection_notNormalized);
    
    return half4(uniforms.textColor * lightContribution, alpha * uniforms.textOpacity);
}



[[early_fragment_tests]]
fragment half3 interfaceSurfaceFragmentShader(SurfaceInOut in [[ stage_in ]],
                                              
                                              constant GlobalFragmentUniforms &globalUniforms [[ buffer(0) ]],
                                              constant FragmentUniforms       &uniforms       [[ buffer(1) ]])
{
    half normal_lengthSquared       = length_squared(in.normal_notNormalized);
    half eyeDirection_lengthSquared = length_squared(in.eyeDirection_notNormalized);

    half3 lightContribution = ColorUtilities::getLightContribution(globalUniforms.lightDirection,
                                                                   globalUniforms.directionalLightColor,
                                                                   globalUniforms.ambientLightColor,
                                                                   uniforms.surfaceShininess,

                                                                   normal_lengthSquared,
                                                                   in.normal_notNormalized,
                                                                   eyeDirection_lengthSquared,
                                                                   in.eyeDirection_notNormalized);

    return uniforms.surfaceColor * lightContribution;
}

//
//  InterfacePreprocessing.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/2/21.
//

#include <metal_stdlib>
#include "../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

typedef struct {
    float4x4 projectionTransforms[1];
    float4x3 eyeDirectionTransforms[1];
    half3x3  normalTransform;
    
    float2   controlPoints[4];
} VertexUniforms;

typedef struct {
    float4x4 projectionTransforms[2];
    float4x3 eyeDirectionTransforms[2];
    half3x3  normalTransform;
    
    float2   controlPoints[4];
} VRVertexUniforms;



#define CREATE_INTERFACE_SURFACE_MESHES_PARAMS(EyeDirection, VertexUniforms)    \
constant VertexUniforms *vertexUniforms      [[ buffer(0) ]],                   \
constant half2          *cornerNormals       [[ buffer(1) ]],                   \
constant uint           &numSurfacesTimes256 [[ buffer(2) ]],                   \
                                                                                \
device   float4         *vertices            [[ buffer(3) ]],                   \
device   EyeDirection   *eyeDirections       [[ buffer(4) ]],                   \
device   half3          *normals             [[ buffer(5) ]],                   \
                                                                                \
uint id [[ thread_position_in_grid ]]                                           \

template <typename EyeDirection, typename VertexUniforms, ushort amplificationCount>
void createInterfaceSurfaceMeshesCommon(CREATE_INTERFACE_SURFACE_MESHES_PARAMS(EyeDirection, VertexUniforms))
{
    uint   iid;
    ushort vid;
    
    if (id < numSurfacesTimes256)
    {
        iid = id >> 8;
        vid = ushort(id) & 255;
    }
    else
    {
        ushort adjusted_id = id - numSurfacesTimes256;
        
        iid = adjusted_id >> 4;
        vid = (ushort(id) & 15) + 256;
    }
    
    ushort position_id = vid >> 1;
    ushort quadrant_id = position_id & 3;
    ushort id_in_quadrant = position_id >> 2;
    
    
    
    auto selectedUniforms = vertexUniforms + iid;
    
    float2 controlPointsX = selectedUniforms->controlPoints[quadrant_id];
    float2 controlPointsY = selectedUniforms->controlPoints[(quadrant_id + 1) & 3];
    
    float3 position;
    half2  normal;
    
    if (id_in_quadrant < 3)
    {
        ushort x_index = id_in_quadrant >> 1;
        ushort y_index = id_in_quadrant & 1;
        
        position.x = controlPointsX[x_index];
        position.y = controlPointsY[y_index];
        
        normal.x = select(0, 1, x_index);
        normal.y = select(0, 1, y_index);
    }
    else
    {
        normal.xy = cornerNormals[id_in_quadrant - 2];
        
        half deltaX = half(controlPointsX[1]) - half(controlPointsX[0]);
        half deltaY = half(controlPointsY[1]) - half(controlPointsY[0]);
        
        position.x = fma(float(deltaX), float(normal.x), controlPointsX[0]);
        position.y = fma(float(deltaY), float(normal.y), controlPointsY[0]);
    }
    
    if (quadrant_id & 1)
    {
        position.xy = position.yx;
        normal.xy   = normal.yx;
    }
    
    constexpr half2 signs[4] = {
        {  1,  1 },
        { -1,  1 },
        { -1, -1 },
        {  1, -1 }
    };
    
    half2 selectedSigns = signs[quadrant_id];
    position.xy = copysign(position.xy, float2(selectedSigns));
    normal.xy   = copysign(normal.xy,          selectedSigns);
    
    
    
    uint bufferIndex = (iid << 8) + (iid << 4) + vid;
    
    position.z = select(0.5, -0.5, vid & 1);
    
    if (vid & 1)
    {
        half3 outNormal;
        
        if (id_in_quadrant == 0)
        {
            outNormal = selectedUniforms->normalTransform[2];
            
            if (quadrant_id & 1) { outNormal = -outNormal; }
        }
        else
        {
            outNormal = fma(selectedUniforms->normalTransform[0],  normal.x,
                            selectedUniforms->normalTransform[1] * normal.y);
        }
        
        normals[bufferIndex >> 1] = outNormal;
    }
    
    vertices     [bufferIndex] =              selectedUniforms->projectionTransforms  [0] * float4(position, 1);
    eyeDirections[bufferIndex] = EyeDirection(selectedUniforms->eyeDirectionTransforms[0] * float4(position, 1));
}



kernel void createInterfaceSurfaceMeshes(CREATE_INTERFACE_SURFACE_MESHES_PARAMS(half3, VertexUniforms))
{
    createInterfaceSurfaceMeshesCommon<half3, VertexUniforms, 1>(vertexUniforms, cornerNormals, numSurfacesTimes256,
                                                                             vertices, eyeDirections, normals, id);
}

kernel void createInterfaceVRSurfaceMeshes(CREATE_INTERFACE_SURFACE_MESHES_PARAMS(float3, VRVertexUniforms))
{
    createInterfaceSurfaceMeshesCommon<float3, VRVertexUniforms, 2>(vertexUniforms, cornerNormals, numSurfacesTimes256,
                                                                               vertices, eyeDirections, normals, id);
}

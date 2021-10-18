//
//  HandDetection.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#include <metal_stdlib>
#include "../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

typedef struct {
    float4x4 cameraToWorldTransform;
    uchar    handIsDetected;
    bool     segmentationTextureHasValues;
    
    float3   handCenter;
    float3   jointPositions[21];
    half3    colors[7];
} ComputeUniforms;

constant uchar NUM_TEX_COORD_OFFSETS = 45;

constant short2 texCoordOffsets[NUM_TEX_COORD_OFFSETS] = {
    // Distance: 0
    short2( 0,  0),
    
    // Distance: 1
    short2( 1,  0),
    short2( 0,  1),
    short2(-1,  0),
    short2( 0, -1),
    
    // Distance: 1.4
    short2( 1,  1),
    short2(-1,  1),
    short2(-1, -1),
    short2( 1, -1),
    
    // Distance: 2
    short2( 2,  0),
    short2( 0,  2),
    short2(-2,  0),
    short2( 0, -2),
    
    // Distance: 2.2
    short2( 2,  1),
    short2( 1,  2),
    short2(-1,  2),
    short2(-2,  1),

    short2(-2, -1),
    short2(-1, -2),
    short2( 1, -2),
    short2( 2, -1),

    // Distance: 2.8
    short2( 2,  2),
    short2(-2,  2),
    short2(-2, -2),
    short2( 2, -2),

    // Distance: 3
    short2( 3,  0),
    short2( 0,  3),
    short2(-3,  0),
    short2( 0, -3),

    // Distance: 3.2
    short2( 3,  1),
    short2( 1,  3),
    short2(-1,  3),
    short2(-3,  1),

    short2(-3, -1),
    short2(-1, -3),
    short2( 1, -3),
    short2( 3, -1),

    // Distance: 3.6
    short2( 3,  2),
    short2( 2,  3),
    short2(-2,  3),
    short2(-3,  2),

    short2(-3, -2),
    short2(-2, -3),
    short2( 2, -3),
    short2( 3, -2),
};



inline short2 convertFloatCoordsToInteger(float2 in)
{
    return short2(rint(fma(in, float2(256, 192), -0.5)));
}

inline float2 convertIntegerCoordsToFloat(short2 in)
{
    return fma(float2(in), float2(1.0 / 256, 1.0 / 192), float2(0.5 / 256, 0.5 / 192));
}

kernel void sampleJointDepths1(device ComputeUniforms &uniforms [[ buffer(0) ]],
                               
                               texture2d<half,  access::sample> colorTextureY    [[ texture(0) ]],
                               texture2d<half,  access::sample> colorTextureCbCr [[ texture(1) ]],
                               texture2d<float, access::sample> depthTexture     [[ texture(2) ]],
                               
                               // threadgroup size must be 32
                               ushort id        [[threadgroup_position_in_grid]],
                               ushort thread_id [[thread_index_in_simdgroup]])
{
    float2 texCoords = uniforms.jointPositions[id].xy;
    texCoords.y = 1 - texCoords.y;
    
    constexpr sampler depthSampler(filter::bicubic);
    threadgroup bool shouldReturnEarly[1];
    float depth;
    
    if (thread_id == 0)
    {
        ushort colorID = __UINT16_MAX__;
        
        if (id <= 2)
        {
            colorID = id;
        }
        else if ((id & 0b11) == 1)
        {
            colorID = (id >> 2) + 2;
        }
        
        if (colorID != __UINT16_MAX__)
        {
            constexpr sampler colorSampler(filter::linear);
            
            half  luma   = colorTextureY   .sample(colorSampler, texCoords).r;
            half2 chroma = colorTextureCbCr.sample(colorSampler, texCoords).rg;
            
            half3 colorRGB = ColorUtilities::convertYCbCr_toRGB(chroma, luma);
            
            uniforms.colors[colorID] = colorRGB;
        }
        
        
        
        depth = depthTexture.sample(depthSampler, texCoords).r;
        
        if (depth <= 0.8)
        {
            uniforms.jointPositions[id].y = texCoords.y;
            uniforms.jointPositions[id].z = depth;
            *shouldReturnEarly = true;
        }
        else
        {
            *shouldReturnEarly = false;
        }
    }
    
    if (*shouldReturnEarly || thread_id >= 8) { return; }
    short2 baseIntegerCoords = convertFloatCoordsToInteger(texCoords);
    
    threadgroup uint smallestThreadIndex[1];
    *smallestThreadIndex = __UINT32_MAX__;
    
    for (uint i = thread_id; i < NUM_TEX_COORD_OFFSETS; i += 8)
    {
        short2 currentIntegerCoords = baseIntegerCoords + texCoordOffsets[i];
        currentIntegerCoords = clamp(currentIntegerCoords, 0, short2(255, 191));
        
        float retrievedDepth = depthTexture.read(as_type<ushort2>(currentIntegerCoords)).r;
        if (retrievedDepth <= 0.8)
        {
            auto atomicSmallestThreadIndexRef = reinterpret_cast<threadgroup atomic_uint*>(smallestThreadIndex);
            atomic_fetch_min_explicit(atomicSmallestThreadIndexRef, thread_id, memory_order_relaxed);
        }
        
        simdgroup_barrier(mem_flags::mem_threadgroup);
        
        if (*smallestThreadIndex == thread_id)
        {
            float2 currentFloatCoords = convertIntegerCoordsToFloat(currentIntegerCoords);
            uniforms.jointPositions[id] = float3(currentFloatCoords, retrievedDepth);
            
            *shouldReturnEarly = true;
        }
        
        if (*shouldReturnEarly) { return; }
    }
    
    if (thread_id == 0)
    {
        uniforms.jointPositions[id].y = texCoords.y;
        uniforms.jointPositions[id].z = depth;
    }
}



kernel void locateHandCenter(device ComputeUniforms &uniforms [[ buffer(0) ]],
                             
                             texture2d<float, access::sample> depthTexture        [[ texture(2) ]],
                             texture2d<half,  access::sample> segmentationTexture [[ texture(3) ]],
                             
                             // threadgroup size must be 64
                             ushort thread_id [[thread_position_in_threadgroup]])
{
    if (thread_id >= 42) { return; }
    threadgroup float depths[21];
    
    if (thread_id < 21)
    {
        float depth = reinterpret_cast<device float*>(uniforms.jointPositions + thread_id)[2];
        depths[thread_id] = (depth <= 0.8) ? depth : NAN;
    }
    
    threadgroup bool shouldReturnEarly[1];
    *shouldReturnEarly = true;
    
    ushort depth_id = thread_id >> 1;
    bool isHelperThread = (thread_id & 1) != 0;
    threadgroup_barrier(mem_flags::mem_threadgroup);
    
    
    
    threadgroup ushort2 tg_medianData[21];
    float thread_depth = depths[depth_id];
    ushort2 thread_medianData;
    
    if (isnan(thread_depth))
    {
        thread_medianData = ushort(0);
        tg_medianData[depth_id] = ushort2(0);
    }
    else
    {
        ushort2 numLessGreater(1);
        ushort2 i_range = select(ushort2(0, 11), { 11, 21 }, isHelperThread);

        for (ushort i = i_range[0]; i < i_range[1]; ++i)
        {
            float retrievedDepth = depths[i];

            if (!isnan(retrievedDepth) && i != depth_id)
            {
                numLessGreater += select(ushort2(1, 0), { 0, 1 }, retrievedDepth < thread_depth);
            }
        }
        
        if (isHelperThread) { tg_medianData[depth_id] = numLessGreater; }
        threadgroup_barrier(mem_flags::mem_threadgroup);
        
        if (!isHelperThread)
        {
            numLessGreater += tg_medianData[depth_id];
            
            thread_medianData = ushort2(depth_id, numLessGreater[0] * numLessGreater[1]);
            tg_medianData[depth_id] = thread_medianData;
        }

        *shouldReturnEarly = false;
    }
    
    threadgroup_barrier(mem_flags::mem_threadgroup);
    if (*shouldReturnEarly)
    {
        if (thread_id == 0) { uniforms.handIsDetected = false; }
        return;
    }
    
    
    
    auto tg_medianMasks = reinterpret_cast<threadgroup uint*>(tg_medianData);
    
    if (depth_id < 5 && !isHelperThread)
    {
        uint thread_medianMask = as_type<uint>(thread_medianData);
        tg_medianMasks[depth_id] = max(tg_medianMasks[depth_id + 16], thread_medianMask);
    }
    
    if (thread_id >= 8) { return; }
    
    auto selectedMaskPointer = tg_medianMasks + thread_id;
    *selectedMaskPointer = max(*selectedMaskPointer, selectedMaskPointer[8]);
    
    constexpr half jointWeights[8] = {
        0.375, 0.062, 0.063, 0.125,
        0.125, 0.125, 0.125, 0.000
    };
    
    constexpr ushort jointIndices[8] = {
        0,  1,  2,  5,
        9, 13, 17,  0
    };
    
    constexpr half colorWeights[8] = {
        0.250, 0.125, 0.125, 0.125,
        0.125, 0.125, 0.125, 0.000
    };
    
    constexpr ushort colorIndices[8] = {
        0, 1, 2, 3,
        4, 5, 6, 0
    };
    
    threadgroup half2 tg_positions[8];
    threadgroup half3 tg_colors[8];
    
    auto selectedPositionPointer = tg_positions + thread_id;
    auto selectedColorPointer    = tg_colors    + thread_id;
    
    auto jointPositionPointer = uniforms.jointPositions + jointIndices[thread_id];
    *selectedPositionPointer = jointWeights[thread_id] * half2(*reinterpret_cast<device float2*>(jointPositionPointer));
    *selectedColorPointer    = colorWeights[thread_id] * uniforms.colors[colorIndices[thread_id]];
    
    for (ushort i = 4; i > 0; i >>= 1)
    {
        if (thread_id >= i) { return; }
        
        *selectedMaskPointer = max(*selectedMaskPointer, selectedMaskPointer[i]);
        
        *selectedPositionPointer += selectedPositionPointer[i];
        *selectedColorPointer    += selectedColorPointer[i];
    }
    
    
    
    float medianDepth = depths[tg_medianData->x];
    half2 averagePosition = *tg_positions;
    half3 averageColor = *tg_colors;
    
    constexpr sampler textureSampler(filter::bicubic);
    float sampleDepth = depthTexture.sample(textureSampler, float2(averagePosition)).r;
    
    if (sampleDepth > 0.8 || abs(sampleDepth - medianDepth) > 0.1)
    {
        uniforms.handCenter = float3(float2(averagePosition), NAN);
        uniforms.handIsDetected = 2;
        return;
    }
    
    if (segmentationTexture.sample(textureSampler, float2(averagePosition)).r == 1)
    {
        uniforms.segmentationTextureHasValues = true;
    }
    else
    {
        uniforms.segmentationTextureHasValues = false;
    }
    
    uniforms.colors[0] = averageColor;
    uniforms.handCenter = float3(float2(averagePosition), sampleDepth);
    uniforms.handIsDetected = true;
}



kernel void sampleJointDepths2(device ComputeUniforms &uniforms [[ buffer(0) ]],
                               
                               texture2d<float, access::read>   depthTexture        [[ texture(2) ]],
                               texture2d<half,  access::sample> segmentationTexture [[ texture(3) ]],
                               
                               // threadgroup size must be 32
                               ushort id        [[threadgroup_position_in_grid]],
                               ushort thread_id [[thread_index_in_simdgroup]])
{
    if (thread_id != 0) { return; }
    
    if (uniforms.handIsDetected != 1)
    {
        return;
    }
    
    float centerDepth = uniforms.handCenter.z;
    float3 position = uniforms.jointPositions[id];
    
    float3 fallbackCoords[2];
    fallbackCoords[0].z = NAN;
    fallbackCoords[1].z = NAN;
    
    bool segmentationTextureHasValues = uniforms.segmentationTextureHasValues;
    threadgroup bool shouldReturnEarly[1];
    *shouldReturnEarly = false;
    
    if (thread_id == 0 && position.z <= 0.8)
    {
        fallbackCoords[0] = position;
        
        if (abs(position.z - centerDepth) <= 0.15)
        {
            fallbackCoords[1] = position;
            
            constexpr sampler segmentationSampler(filter::linear);
            
            if (!segmentationTextureHasValues ||
                 segmentationTexture.sample(segmentationSampler, position.xy).r == 1)
            {
                *shouldReturnEarly = true;
            }
        }
    }
    
    if (*shouldReturnEarly || thread_id >= 12) { return; }
    short2 baseIntegerCoords = convertFloatCoordsToInteger(position.xy);
    
    threadgroup uint smallestThreadIndex[1];
    *smallestThreadIndex = __UINT32_MAX__;
    auto atomicSmallestThreadIndexRef = reinterpret_cast<threadgroup atomic_uint*>(smallestThreadIndex);
    
    for (uint i = thread_id; i < NUM_TEX_COORD_OFFSETS; i += 12)
    {
        short2 currentIntegerCoords = baseIntegerCoords + texCoordOffsets[i];
        currentIntegerCoords = clamp(currentIntegerCoords, 0, short2(255, 191));
        
        float retrievedDepth = depthTexture.read(as_type<ushort2>(currentIntegerCoords)).r;
        float2 currentFloatCoords;
        
        while (true)
        {
            if (retrievedDepth > 0.8) { break; }
            
            currentFloatCoords = convertIntegerCoordsToFloat(currentIntegerCoords);
            if (isnan(fallbackCoords[0].z)) { fallbackCoords[0] = float3(currentFloatCoords, retrievedDepth); }
            
            if (abs(retrievedDepth - centerDepth) > 0.15) { break; }
            if (isnan(fallbackCoords[1].z)) { fallbackCoords[1] = float3(currentFloatCoords, retrievedDepth); }
            
            if (!segmentationTextureHasValues ||
                 segmentationTexture.read(as_type<ushort2>(currentIntegerCoords)).r == 0) { break; }
            
            atomic_fetch_min_explicit(atomicSmallestThreadIndexRef, thread_id, memory_order_relaxed);
            break;
        }
        
        simdgroup_barrier(mem_flags::mem_threadgroup);
        
        if (*smallestThreadIndex == thread_id)
        {
            uniforms.jointPositions[id] = float3(currentFloatCoords, retrievedDepth);
            *shouldReturnEarly = true;
        }
        
        if (*shouldReturnEarly) { return; }
    }
    
    for (char i = 1; i >= 0; --i)
    {
        if (!isnan(fallbackCoords[i].z))
        {
            atomic_fetch_min_explicit(atomicSmallestThreadIndexRef, thread_id, memory_order_relaxed);
        }
        
        simdgroup_barrier(mem_flags::mem_threadgroup);
        
        if (*smallestThreadIndex == thread_id)
        {
            uniforms.jointPositions[id] = fallbackCoords[i];
            *shouldReturnEarly = true;
        }
        
        if (*shouldReturnEarly) { return; }
    }
}

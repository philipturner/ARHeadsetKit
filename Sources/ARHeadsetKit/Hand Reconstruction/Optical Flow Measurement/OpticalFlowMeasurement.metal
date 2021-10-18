//
//  OpticalFlowMeasurement.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 5/28/21.
//

#include <metal_stdlib>
#include "OpticalFlowMeasurementTypes.metal"
using namespace metal;

kernel void poolOpticalFlow256(device half3 *regionSamples256  [[ buffer(0) ]],
                               
                               texture2d<float, access::read>       depthTexture0        [[ texture(0) ]],
                               texture2d<float, access::read>       depthTexture1        [[ texture(1) ]],
                               texture2d<float, access::read>       depthTexture2        [[ texture(2) ]],
                               
                               texture2d<half,  access::read_write> segmentationTexture0 [[ texture(3) ]],
                               texture2d<half,  access::read>       segmentationTexture1 [[ texture(4) ]],
                               texture2d<half,  access::read>       segmentationTexture2 [[ texture(5) ]],
                               
                               // grid size must be (64, 96)
                               // threadgroup size must be (4, 8)
                               ushort2 id        [[ thread_position_in_grid ]],
                               ushort2 tg_id     [[ threadgroup_position_in_grid ]],
                               ushort  thread_id [[ thread_index_in_simdgroup ]])
{
    ushort3 oldMasks(0);
    ushort3 newMasks(0);
    
    ushort2 coordStart = id << ushort2(2, 1);

    for (uchar row = 0; row < 2; ++row)
    {
        for (uchar column = 0; column < 4; ++column)
        {
            ushort2 tempCoords = coordStart + ushort2(column, row);

            half3 segmentationValues = {
                segmentationTexture0.read(tempCoords).r,
                segmentationTexture1.read(tempCoords).r,
                segmentationTexture2.read(tempCoords).r
            };

            segmentationTexture0.write(half4{ segmentationValues[2] }, tempCoords);

            bool3 comparisons = segmentationValues == half3(1);
            ushort selectionMask = 1 << ((row << 2) + column);

            ushort3 vectorMask1(ushort2(selectionMask), 0);

            if (comparisons[2])
            {
                ushort3 vectorMask2(ushort2(0), selectionMask);
                newMasks |= select(vectorMask1, vectorMask2, comparisons);
            }
            else
            {
                oldMasks |= select(0, vectorMask1, comparisons);
            }
        }
    }
    
    SmallRegionAccumulator accumulator(coordStart);
    
    half3 output;
    output[0] = accumulator.getOpticalFlow(oldMasks[0], depthTexture0);
    accumulator.clearDepthCache();

    output[1] = accumulator.getOpticalFlow(oldMasks[1], depthTexture1);
    accumulator.clearDepthCache();

    output[0] += accumulator.getOpticalFlow(newMasks[0], depthTexture2);
    output[1] += accumulator.getOpticalFlow(newMasks[1], depthTexture2, newMasks[2]);
    output[2]  = accumulator.opticalFlowAndArea[1];
    
    threadgroup half3 shuffledDownOutputs[16];
    
#define REDUCTION_BLOCK(i)                          \
if (thread_id >= i)                                 \
{                                                   \
    shuffledDownOutputs[thread_id - i] = output;    \
    return;                                         \
}                                                   \
                                                    \
simdgroup_barrier(mem_flags::mem_threadgroup);      \
output += shuffledDownOutputs[thread_id];           \

    REDUCTION_BLOCK(16);
    REDUCTION_BLOCK(8);
    REDUCTION_BLOCK(4);
    REDUCTION_BLOCK(2);
    
    shuffledDownOutputs[thread_id] = output;
    
    if (thread_id == 0)
    {
        output += shuffledDownOutputs[1];
        regionSamples256[(tg_id.y << 4) + tg_id.x] = output;
    }
}

kernel void poolOpticalFlow8192(device half3 *regionSamples256  [[ buffer(0) ]],
                                device half3 *regionSamples8192 [[ buffer(1) ]],
                                
                                ushort id        [[ thread_position_in_grid ]],
                                ushort tg_id     [[ threadgroup_position_in_grid ]],
                                ushort thread_id [[ thread_index_in_simdgroup ]])
{
    threadgroup half3 shuffledDownOutputs[16];
    half3 output = regionSamples256[id];
    
    REDUCTION_BLOCK(16);
    REDUCTION_BLOCK(8);
    REDUCTION_BLOCK(4);
    REDUCTION_BLOCK(2);
    
    shuffledDownOutputs[thread_id] = output;
    
    if (thread_id == 0)
    {
        output += shuffledDownOutputs[1];
        regionSamples8192[tg_id] = output;
    }
}

//
//  SceneTexelManagement.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "../../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

kernel void clearTriangleTextureSlots(device ulong4 *triangleTextureSlots [[ buffer(12) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    triangleTextureSlots[id] = ulong4(0);
}

kernel void markTriangleTextureSlots(device bool  *matchExistsMarks          [[ buffer(9) ]],
                                     device uint  *textureSlotIDs            [[ buffer(10) ]],
                                     
                                     device uchar *smallTriangleTextureSlots [[ buffer(11) ]],
                                     device uchar *largeTriangleTextureSlots [[ buffer(12) ]],
                                     
                                     uint id [[ thread_position_in_grid ]])
{
    uint i     = id << 3;
    uint i_end = i + 8;
    
    for (; i < i_end; ++i)
    {
        if (matchExistsMarks[i])
        {
            uint textureSlotID = textureSlotIDs[i];
            device uchar *targetSlots;
            
            if (textureSlotID & (1 << 31))
            {
                textureSlotID &= ~(1 << 31);
                targetSlots = largeTriangleTextureSlots;
            }
            else
            {
                targetSlots = smallTriangleTextureSlots;
            }
            
            targetSlots[textureSlotID] = 1;
        }
    }
}

kernel void findOpenTriangleTextureSlots(device ulong4      *slots             [[ buffer(11) ]],
                                         device uint        *openSlotIDs       [[ buffer(12) ]],
                                         
                                         device atomic_uint *totalNumOpenSlots [[ buffer(13) ]],
                                         
                                         // threadgroup must be 32
                                         uint   id        [[ thread_position_in_grid ]],
                                         ushort thread_id [[ thread_index_in_threadgroup ]])
{
    ulong4 retrievedSlots = slots[id];
    ushort4 slotCounts = ushort4(popcount(as_type<uint4>(retrievedSlots.xy)));
    slotCounts        += ushort4(popcount(as_type<uint4>(retrievedSlots.zw)));
    
    slotCounts.xy += slotCounts.zw;
    slotCounts[0] += slotCounts[1];
    
    ushort numOpenSlots = 32 - slotCounts[0];
    
    
    
    threadgroup uint tg_numOpenSlots[1];
    *tg_numOpenSlots = 0;
    
    simdgroup_barrier(mem_flags::mem_threadgroup);
    
    auto atomicNumOpenSlotsRef = reinterpret_cast<threadgroup atomic_uint*>(tg_numOpenSlots);
    ushort withinThreadgroupOffset = atomic_fetch_add_explicit(atomicNumOpenSlotsRef, numOpenSlots, memory_order_relaxed);
    
    simdgroup_barrier(mem_flags::mem_threadgroup);
    
    threadgroup uint tg_totalOffset[1];
    
    if (thread_id == 0)
    {
        *tg_totalOffset = atomic_fetch_add_explicit(totalNumOpenSlots, *tg_numOpenSlots, memory_order_relaxed);
    }
    
    simdgroup_barrier(mem_flags::mem_threadgroup);
    
    uint totalOffset = *tg_totalOffset + withinThreadgroupOffset;

    
    
    uint baseSlotID = id << 5;
    
    for (ushort i = 0; i < 32; ++i)
    {
        if (!as_type<vec<uchar, 32>>(retrievedSlots)[i])
        {
            openSlotIDs[totalOffset] = baseSlotID + i;
            ++totalOffset;
        }
    }
}



kernel void countTriangleSizes16(device   uchar  *columnCounts               [[ buffer(0) ]],
                                 device   float3 *rasterizationComponents    [[ buffer(1) ]],
                                 constant uint   &triangleCount              [[ buffer(2) ]],
                                 
                                 device   uchar4 *triangleCounts16           [[ buffer(3) ]],
                                 device   ushort *sizeMarks                  [[ buffer(4) ]],
                                 device   ushort *compressedHaveChangedMarks [[ buffer(5) ]],
                                 
                                 uint id [[ thread_position_in_grid ]])
{
    uint i     = id << 4;
    uint i_end = min(i + 16, triangleCount);
    
    ushort cacheIndex = 0;
    ushort4 counts16(0);
    
    ushort sizeMark = 0;
    ushort haveChangedMark = compressedHaveChangedMarks[id];
    
    for (; i < i_end; ++i)
    {
        ushort mask = 1 << cacheIndex;
        bool shouldIncrementLargeTriangleCounts = true;
        
        if (columnCounts[i] <= 6)
        {
            float orthogonalComponent = rasterizationComponents[i].z;
            
            if (ceil(orthogonalComponent) <= 5)
            {
                ++counts16[0];
                shouldIncrementLargeTriangleCounts = false;
                
                if (haveChangedMark & mask) { ++counts16[2]; }
            }
        }
        
        if (shouldIncrementLargeTriangleCounts)
        {
            ++counts16[1];
            sizeMark |= mask;
            
            if (haveChangedMark & mask) { ++counts16[3]; }
        }
        
        ++cacheIndex;
    }
    
    triangleCounts16[id] = uchar4(counts16);
    sizeMarks       [id] = sizeMark;
}

kernel void countTriangleSizes64(device uint4  *counts16 [[ buffer(3) ]],
                                 device uchar4 *counts64 [[ buffer(4) ]],
                                 
                                 uint id [[ thread_position_in_grid ]])
{
    uint4 counts = counts16[id];
    counts.xy += counts.zw;
    counts[0] += counts[1];
    
    counts64[id] = as_type<uchar4>(counts[0]);
}

kernel void countTriangleSizes512(device uint4   *counts64  [[ buffer(4) ]],
                                  device ushort4 *counts512 [[ buffer(5) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    uint countIndex = id << 1;
    uint4 counts = counts64[countIndex] + counts64[countIndex + 1];
    
    ushort4 output = ushort4(as_type<uchar4>(counts[0]));
    
    for (uchar i = 1; i < 4; ++i)
    {
        output += ushort4(as_type<uchar4>(counts[i]));
    }
    
    counts512[id] = output;
}

kernel void scanTriangleSizes4096(device vec<ulong, 8> *counts512  [[ buffer(5) ]],
                                  device ushort4       *counts4096 [[ buffer(6) ]],
                                  device vec<uint, 8>  *offsets512 [[ buffer(7) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    auto counts = counts512[id];
    vec<uint, 8> offsets1 = { 0 };
    vec<uint, 8> offsets2 = { 0 };
    
    for (uchar i = 0; i < 7; ++i)
    {
        offsets1[i + 1] = offsets1[i] + as_type<uint2>(counts[i])[0];
        offsets2[i + 1] = offsets2[i] + as_type<uint2>(counts[i])[1];
    }
    
    offsets512[id] = offsets2;
    counts4096[id] = as_type<ushort4>(uint2(
        offsets1[7] + as_type<uint2>(counts[7])[0],
        offsets2[7] + as_type<uint2>(counts[7])[1]
    ));
}



kernel void markTriangleSizeOffsets512(device ushort2      *offsets512 [[ buffer(0) ]],
                                       device vec<uint, 8> *offsets64  [[ buffer(1) ]],
                                       device vec<uint, 8> *counts64   [[ buffer(2) ]],
                                       
                                       uint id [[ thread_position_in_grid ]])
{
    auto counts = counts64[id];
    vec<uint, 8> offsets = { as_type<uint>(offsets512[id]) };
    
    for (uchar i = 0; i < 7; ++i)
    {
        offsets[i + 1] = offsets[i] + as_type<uint>(ushort2(as_type<uchar4>(counts[i]).zw));
    }
    
    offsets64[id] = offsets;
}

kernel void markTriangleSizeOffsets64(device ushort2 *offsets64 [[ buffer(1) ]],
                                      device uint4   *offsets16 [[ buffer(2) ]],
                                      device uint3   *counts16  [[ buffer(3) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    uint3 counts = counts16[id].xyz;
    uint4 offsets = { as_type<uint>(offsets64[id]) };
    
    for (uchar i = 0; i < 3; ++i)
    {
        offsets[i + 1] = offsets[i] + as_type<uint>(ushort2(as_type<uchar4>(counts[i]).zw));
    }
    
    offsets16[id] = offsets;
}

kernel void markTriangleSizeOffsets16(device   ushort2 *offsets16                  [[ buffer(2) ]],
                                      constant uint2   *offsets4096                [[ buffer(3) ]],
                                      device   ushort  *sizeMarks                  [[ buffer(4) ]],
                                      device   ushort  *compressedHaveChangedMarks [[ buffer(5) ]],
                                      
                                      constant uint    &triangleCount              [[ buffer(6) ]],
                                      device   ushort2 *textureOffsets             [[ buffer(7) ]],
                                      device   uint    *textureSlotIDs             [[ buffer(8) ]],
                                      device   uint    *newToOldTriangleMatches    [[ buffer(9) ]],
                                      
                                      device   uint    *oldTextureSlotIDs          [[ buffer(10) ]],
                                      device   uint    *openSmallTriangleSlotIDs   [[ buffer(11) ]],
                                      device   uint    *openLargeTriangleSlotIDs   [[ buffer(12) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    uint i     = id << 4;
    uint i_end = min(i + 16, triangleCount);
    
    ushort cacheIndex = 0;
    uint2 offsets = offsets4096[id >> 8] + uint2(offsets16[id]);
    
    ushort sizeMark        = sizeMarks[id];
    ushort haveChangedMark = compressedHaveChangedMarks[id];
    
    for (; i < i_end; ++i)
    {
        ushort mask = 1 << cacheIndex;
        bool isLarge = sizeMark & mask;
        
        uint textureSlotID;
        
        if (haveChangedMark & mask)
        {
            if (isLarge)
            {
                textureSlotID = openLargeTriangleSlotIDs[offsets[1]];
                ++offsets[1];
            }
            else
            {
                textureSlotID = openSmallTriangleSlotIDs[offsets[0]];
                ++offsets[0];
            }
        }
        else
        {
            uint matchedTriangleID = newToOldTriangleMatches[i];
            textureSlotID = oldTextureSlotIDs[matchedTriangleID];
        }
        
        ushort2 textureOffset;
        
        if (isLarge)
        {
            reinterpret_cast<thread ushort2&>(textureSlotID)[1] &= ~(1 << 15);
            
            textureOffset.y = ushort(textureSlotID >> 9);
            textureOffset.x = ushort(textureSlotID) & 511;
            
            textureOffset.y = (textureOffset.y << 4) - (textureOffset.y << 1) + ushort(0x8000 | 1);
            textureOffset.x = (textureOffset.x << 4) + 1;
            
            reinterpret_cast<thread ushort2&>(textureSlotID)[1] |= 1 << 15;
        }
        else
        {
            textureOffset.y = ushort(textureSlotID >> 10);
            textureOffset.x = ushort(textureSlotID) & 1023;
            
            textureOffset.y = (textureOffset.y << 3) - textureOffset.y + 1;
            textureOffset.x = (textureOffset.x << 3) + 1;
        }
        
        textureOffsets[i] = textureOffset;
        textureSlotIDs[i] = textureSlotID;
        
        ++cacheIndex;
    }
}



kernel void markColorCopyingRowSizes(constant bool        &copyingLargeTriangles   [[ buffer(0) ]],
                                     device   atomic_uint *rowHeightMarks          [[ buffer(1) ]],
                                     
                                     device   uint        *oldTextureSlotIDs       [[ buffer(2) ]],
                                     device   bool        *matchExistsMarks        [[ buffer(3) ]],
                                     device   float4      *rasterizationComponents [[ buffer(4) ]],
                                     
                                     uint id [[ thread_position_in_grid ]])
{
    uint slotID = oldTextureSlotIDs[id];
    
    if (bool(slotID & (1 << 31)) == copyingLargeTriangles && matchExistsMarks[id])
    {
        reinterpret_cast<thread ushort2&>(slotID)[1] &= ~(1 << 15);
        
        uint height = min(ushort(ceil(rasterizationComponents[id].z)), ushort(12));
        ushort rowID = slotID >> select(7, 6, copyingLargeTriangles);
        
        atomic_fetch_max_explicit(rowHeightMarks + rowID, height, memory_order_relaxed);
    }
}

kernel void reduceColorCopyingRowSizes(device uint  *rowHeightMarks    [[ buffer(1) ]],
                                       device uchar *reducedRowHeights [[ buffer(2) ]],
                                       
                                       // threadgroup size must be 8
                                       uint   id        [[ thread_position_in_grid ]],
                                       ushort tgid      [[ threadgroup_position_in_grid ]],
                                       ushort thread_id [[ thread_index_in_threadgroup ]])
{
    threadgroup uint tg_maxRowHeight[1];
    *tg_maxRowHeight = 0;
    
    simdgroup_barrier(mem_flags::mem_threadgroup);
    
    auto maxRowHeightRef = reinterpret_cast<threadgroup atomic_uint*>(tg_maxRowHeight);
    atomic_fetch_max_explicit(maxRowHeightRef, rowHeightMarks[id], memory_order_relaxed);
    
    simdgroup_barrier(mem_flags::mem_threadgroup);
    
    if (thread_id == 0)
    {
        reducedRowHeights[tgid] = *tg_maxRowHeight + 2;
    }
}

kernel void transferColorDataToTexture(device   ushort2 *textureOffsets          [[ buffer(0) ]],
                                       device   bool    *haveChangedMarks        [[ buffer(1) ]],
                                       
                                       device   uchar4  *lumaBuffer              [[ buffer(2) ]],
                                       device   uchar2  *chromaBuffer            [[ buffer(3) ]],
                                       device   uchar   *columnCounts            [[ buffer(4) ]],
                                       
                                       device   ushort  *texelOffsets            [[ buffer(5) ]],
                                       device   ushort  *columnOffsets           [[ buffer(6) ]],
                                       constant uint    *texelOffsets256         [[ buffer(7) ]],
                                       constant uint    *columnOffsets256        [[ buffer(8) ]],
                                       device   uchar   *expandedColumnOffsets   [[ buffer(9) ]],
                                       
                                       device  uchar2   *smallTriangleLumaRows   [[ buffer(10) ]],
                                       device  uchar2   *largeTriangleLumaRows   [[ buffer(11) ]],
                                       device  uchar2   *smallTriangleChromaRows [[ buffer(12) ]],
                                       device  uchar2   *largeTriangleChromaRows [[ buffer(13) ]],
                                       
                                       uint id [[ thread_position_in_grid ]])
{
    if (!haveChangedMarks[id]) { return; }
    
    uint id_over_256 = id >> 8;
    uint texelOffset  = texelOffsets256 [id_over_256] + texelOffsets [id];
    uint columnOffset = columnOffsets256[id_over_256] + columnOffsets[id];
    uint columnEnd    = columnOffset + columnCounts[id];

    auto lumaTexels   = lumaBuffer   + texelOffset;
    auto chromaTexels = chromaBuffer + texelOffset;
    
    device uchar2 *lumaRows;
    device uchar2 *chromaRows;
    
    ushort2 textureStart = textureOffsets[id];
    
    if (textureStart.y & 0x8000)
    {
        textureStart.y &= 0x7FFF;
        
        lumaRows   = largeTriangleLumaRows;
        chromaRows = largeTriangleChromaRows;
    }
    else
    {
        lumaRows   = smallTriangleLumaRows;
        chromaRows = smallTriangleChromaRows;
    }
    
    SceneColorReconstruction::YCbCrTexture texture(lumaRows, chromaRows);
    
    ushort previousExpandedColumnOffset = 0;
    ushort nextExpandedColumnOffset = expandedColumnOffsets[columnOffset];

    ushort lastHeight = 0;
    ushort currentHeight = nextExpandedColumnOffset;
    
    // Loop by column
    
    for (; columnOffset < columnEnd; ++columnOffset)
    {
        ushort futureExpandedColumnOffset;
        uint columnOffset_plus_1 = columnOffset + 1;
        
        if (columnOffset_plus_1 < columnEnd) { futureExpandedColumnOffset = expandedColumnOffsets[columnOffset_plus_1]; }
        else                                 { futureExpandedColumnOffset = nextExpandedColumnOffset; }
        
        ushort nextHeight = futureExpandedColumnOffset - nextExpandedColumnOffset;
        ushort offsetY = 0;
        
        // Loop by texel
        
        while (previousExpandedColumnOffset < nextExpandedColumnOffset)
        {
            using namespace SceneColorReconstruction;
            
            Texel sampleTexel = {
                lumaTexels  [previousExpandedColumnOffset],
                chromaTexels[previousExpandedColumnOffset]
            };
            
            ushort2 texCoords(textureStart.x, textureStart.y + offsetY);
            ++previousExpandedColumnOffset;
            
            texture.write(sampleTexel, texCoords);
            texture.createPadding(sampleTexel, texCoords,
                                  lastHeight, currentHeight, nextHeight,
                                  offsetY, offsetY);
        }
        
        nextExpandedColumnOffset = futureExpandedColumnOffset;
        
        lastHeight = currentHeight;
        currentHeight = nextHeight;
        
        ++textureStart.x;
    }
}
#endif

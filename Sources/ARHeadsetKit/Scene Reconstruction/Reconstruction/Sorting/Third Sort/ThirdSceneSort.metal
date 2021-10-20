//
//  ThirdSceneSort.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "ThirdSceneSortTypes.metal"
using namespace metal;

kernel void prepareMarkMicroSectors(constant ushort *smallSector256GroupOffsets [[ buffer(0) ]],
                                    device   ushort *smallSectorIDBuffer        [[ buffer(1) ]],
                                    
                                    ushort id [[ thread_position_in_grid ]])
{
    ushort i     = smallSector256GroupOffsets[id];
    ushort i_end = smallSector256GroupOffsets[id + 1];
    
    for (; i < i_end; ++i)
    {
        smallSectorIDBuffer[i] = id;
    }
}



kernel void markMicroSectors(constant ushort      *smallSector256GroupOffsets [[ buffer(0) ]],
                             device   ushort      *smallSectorIDBuffer        [[ buffer(1) ]],
                             
                             constant ushort      *smallSectorCounts          [[ buffer(2) ]],
                             constant uint        *smallSectorOffsets         [[ buffer(3) ]],
                             constant float2x3    *smallSectorBounds          [[ buffer(4) ]],
                             
                             device   uint        *idBuffer                   [[ buffer(5) ]],
                             device   float3      *worldSpacePositions        [[ buffer(6) ]],
                             
                             device   atomic_uint *atomicCounts               [[ buffer(7) ]],
                             device   void        *subsectorData              [[ buffer(8) ]],
                             
                             uint id [[ thread_position_in_grid ]])
{
    ushort smallSectorID = smallSectorIDBuffer[id >> 4];
    
    uint i     = (id << 4) - (uint(smallSector256GroupOffsets[smallSectorID]) << 8);
    uint i_end = min(uint(smallSectorCounts[smallSectorID]), i + 16);
    
    if (i >= i_end)
    {
        return;
    }
    
    float2x3 bounds = smallSectorBounds[smallSectorID];
    
    uint idBufferOffset = smallSectorOffsets[smallSectorID];
    i     += idBufferOffset;
    i_end += idBufferOffset;
    
    for (; i < i_end; ++i)
    {
        float3 position = worldSpacePositions[idBuffer[i]];
        float2x3 deltas = float2x3(position, position) - bounds;
        deltas *= 4;
        
        short3 upperCoords = clamp(short3(deltas[0]), 0, 7);
        short3 lowerCoords = clamp(short3(deltas[1]), 0, 7);
        
        ushort2 hashXY = ushort2(lowerCoords.xy) << ushort2(6, 3);
        uint lowMicroSectorID = (uint(smallSectorID) << 9) + (hashXY[0] + hashXY[1] + lowerCoords.z);
        
#define FETCH(a) atomic_fetch_add_explicit(counts + a, 1, memory_order_relaxed)
        device atomic_uint *counts = atomicCounts + lowMicroSectorID;
        ushort offset0 = FETCH(0);
        
        bool3 difference = upperCoords > lowerCoords;
        ushort power = Permutation::createPower(difference);
        
        SubsectorDataHandle handle(subsectorData, i);
        handle.writeCommonMetadata(lowMicroSectorID, offset0, power, difference);
        if (power == 0) { continue; }
        
        
        
        ushort offsetX, offsetY, offsetZ;
        
        if (difference.x) { offsetX = FETCH(64); }
        if (difference.y) { offsetY = FETCH( 8); }
        if (difference.z) { offsetZ = FETCH( 1); }
        
        ushort firstOffset;
        
        if      (difference.z) { firstOffset = offsetZ; }
        else if (difference.y) { firstOffset = offsetY; }
        else                   { firstOffset = offsetX; }
        
        handle.writeLowestOffset(firstOffset);
        if (power == 1) { continue; }
        
        
        
        ushort offsetZY, offsetZX, offsetYX;
        
        if (all(difference.yz)) { offsetZY = FETCH(9); }
        if (all(difference.xz)) { offsetZX = FETCH(65); }
        if (all(difference.xy)) { offsetYX = FETCH(72); }
        
        ushort secondOffset = all(difference.yz) ? offsetY : offsetX;
        ushort thirdOffset;
        
        if (power == 2)
        {
            if      (!difference.x) { thirdOffset = offsetZY; }
            else if (!difference.y) { thirdOffset = offsetZX; }
            else                    { thirdOffset = offsetYX; }
        }
        else
        {
            thirdOffset = offsetX;
        }
        
        handle.writeMiddleOffsets({ secondOffset, thirdOffset });
        if (power == 2) { continue; }
        
        
        
        ushort offsetXYZ = FETCH(73);
        handle.writeUpperOffsets({ offsetZY, offsetZX, offsetYX, offsetXYZ });
    }
}

kernel void poolSmallSector128thCounts(device ushort4 *counts512th                   [[ buffer(7) ]],
                                       device ushort  *counts128th                   [[ buffer(9) ]],
                                       device uchar   *numMicroSectors128th          [[ buffer(10) ]],
                                       device uchar   *microSector32GroupCounts128th [[ buffer(11) ]],
                                       
                                       uint id [[ thread_position_in_grid ]])
{
    uint countIndex = id << 1;
    ushort4 counts(counts512th[countIndex].xz,
                   counts512th[countIndex + 1].xz);
    
    ushort2 numMicroSectors = ushort2(counts.xy != 0);
    numMicroSectors        += ushort2(counts.zw != 0);
    
    ushort2 num32Groups = (counts.xy + 31) >> 5;
    num32Groups        += (counts.zw + 31) >> 5;
    
    counts.xy += counts.zw;
    
    counts[0]          += counts[1];
    numMicroSectors[0] += numMicroSectors[1];
    num32Groups[0]     += num32Groups[1];
    
    counts128th                  [id] = counts[0];
    numMicroSectors128th         [id] = numMicroSectors[0];
    microSector32GroupCounts128th[id] = num32Groups[0];
}

kernel void poolSmallSector32ndTo8thCounts(device ushort4 *counts_in                    [[ buffer(9) ]],
                                           device uchar4  *numMicroSectors_in           [[ buffer(10) ]],
                                           device uchar4  *microSector32GroupCounts_in  [[ buffer(11) ]],
                                           
                                           device ushort  *counts_out                   [[ buffer(12) ]],
                                           device uchar   *numMicroSectors_out          [[ buffer(13) ]],
                                           device uchar   *microSector32GroupCounts_out [[ buffer(14) ]],
                                           
                                           uint id [[ thread_position_in_grid ]])
{
    uchar4 rawNumMicroSectors = numMicroSectors_in[id];
    ushort outNumMicroSectors;
    
    if (as_type<uint>(rawNumMicroSectors) == 0)
    {
        outNumMicroSectors = 0;
    }
    else
    {
        ushort4 counts          = counts_in[id];
        ushort4 num32Groups     = ushort4(microSector32GroupCounts_in[id]);
        ushort4 numMicroSectors = ushort4(rawNumMicroSectors);
        
        bool4 validDataMask = numMicroSectors != 0;
        counts      = select(ushort4(0), counts,      validDataMask);
        num32Groups = select(ushort4(0), num32Groups, validDataMask);
        
        counts.xy          += counts.zw;
        num32Groups.xy     += num32Groups.zw;
        numMicroSectors.xy += numMicroSectors.zw;
        
        counts[0]         += counts[1];
        num32Groups[0]    += num32Groups[1];
        outNumMicroSectors = numMicroSectors[0] + numMicroSectors[1];
        
        counts_out                  [id] = counts[0];
        microSector32GroupCounts_out[id] = num32Groups[0];
    }
    
    numMicroSectors_out[id] = outNumMicroSectors;
}

kernel void poolSmallSectorHalfCounts(device ushort4 *counts8th                    [[ buffer(12) ]],
                                      device uchar4  *numMicroSectors8th           [[ buffer(13) ]],
                                      device uchar4  *microSector32GroupCounts8th  [[ buffer(14) ]],
                                      
                                      device ushort  *countsHalf                   [[ buffer(9) ]],
                                      device ushort  *numMicroSectorsHalf          [[ buffer(10) ]],
                                      device ushort  *microSector32GroupCountsHalf [[ buffer(11) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    ushort4 counts = counts8th[id];
    ushort4 numMicroSectors = ushort4(numMicroSectors8th[id]);
    ushort4 num32Groups = ushort4(microSector32GroupCounts8th[id]);
    
    bool4 validDataMask = numMicroSectors != 0;
    counts      = select(ushort4(0), counts,      validDataMask);
    num32Groups = select(ushort4(0), num32Groups, validDataMask);
    
    counts.xy          += counts.zw;
    num32Groups.xy     += num32Groups.zw;
    numMicroSectors.xy += numMicroSectors.zw;
    
    counts[0]          += counts[1];
    num32Groups[0]     += num32Groups[1];
    numMicroSectors[0] += numMicroSectors[1];
    
    countsHalf                  [id] = counts[0];
    microSector32GroupCountsHalf[id] = num32Groups[0];
    numMicroSectorsHalf         [id] = numMicroSectors[0];
}

kernel void scanSmallSectors2(device ushort4 *countsHalf                    [[ buffer(9) ]],
                              device ushort4 *numMicroSectorsHalf           [[ buffer(10) ]],
                              device ushort4 *microSector32GroupCountsHalf  [[ buffer(11) ]],
                              
                              device ushort4 *offsetsHalf                   [[ buffer(12) ]],
                              device ushort4 *microSectorOffsetsHalf        [[ buffer(13) ]],
                              device ushort4 *microSector32GroupOffsetsHalf [[ buffer(14) ]],
                              
                              device ushort  *counts2                       [[ buffer(15) ]],
                              device ushort  *numMicroSectors2              [[ buffer(16) ]],
                              device ushort  *microSector32GroupCounts2     [[ buffer(17) ]],
                              
                              uint id [[ thread_position_in_grid ]])
{
    ushort4 counts          = countsHalf                  [id];
    ushort4 numMicroSectors = numMicroSectorsHalf         [id];
    ushort4 num32Groups     = microSector32GroupCountsHalf[id];
    
    ushort4 offsets                   = { 0, counts[0] };
    ushort4 microSectorOffsets        = { 0, numMicroSectors[0] };
    ushort4 microSector32GroupOffsets = { 0, num32Groups[0] };
    
    for (uchar i = 1; i < 3; ++i)
    {
        offsets                  [i + 1] = offsets                  [i] + counts         [i];
        microSectorOffsets       [i + 1] = microSectorOffsets       [i] + numMicroSectors[i];
        microSector32GroupOffsets[i + 1] = microSector32GroupOffsets[i] + num32Groups    [i];
    }
    
    offsetsHalf                  [id] = offsets;
    microSectorOffsetsHalf       [id] = microSectorOffsets;
    microSector32GroupOffsetsHalf[id] = microSector32GroupOffsets;
    
    offsets[3]                   += counts[3];
    microSectorOffsets[3]        += numMicroSectors[3];
    microSector32GroupOffsets[3] += num32Groups[3];
    
    counts2                  [id] = offsets[3];
    numMicroSectors2         [id] = microSectorOffsets[3];
    microSector32GroupCounts2[id] = microSector32GroupOffsets[3];
}



kernel void markSmallSectorHalfTo32ndOffsets(device ushort3 *counts_in                     [[ buffer(13) ]],
                                             device uchar4  *numMicroSectors_in            [[ buffer(14) ]],
                                             device uchar3  *microSector32GroupCounts_in   [[ buffer(15) ]],
                                             
                                             device ushort2 *offsets_out                   [[ buffer(16) ]],
                                             device ushort2 *microSectorOffsets_out        [[ buffer(17) ]],
                                             device ushort2 *microSector32GroupOffsets_out [[ buffer(18) ]],
                                             
                                             device ushort  *offsets_in                    [[ buffer(19) ]],
                                             device ushort  *microSectorOffsets_in         [[ buffer(20) ]],
                                             device ushort  *microSector32GroupOffsets_in  [[ buffer(21) ]],
                                             
                                             uint id [[ thread_position_in_grid ]])
{
    uchar4 rawNumMicroSectors = numMicroSectors_in[id];
    if (as_type<uint>(rawNumMicroSectors) == 0) { return; }
    
    ushort3 counts          = counts_in[id];
    ushort4 numMicroSectors = ushort4(rawNumMicroSectors);
    ushort3 num32Groups     = ushort3(microSector32GroupCounts_in[id]);
    
    bool3 validDataMask = numMicroSectors.xyz != 0;
    counts      = select(ushort3(0), counts,      validDataMask);
    num32Groups = select(ushort3(0), num32Groups, validDataMask);
    
    ushort4 offsets                   = { offsets_in                  [id] };
    ushort4 microSectorOffsets        = { microSectorOffsets_in       [id] };
    ushort4 microSector32GroupOffsets = { microSector32GroupOffsets_in[id] };
    
    for (uchar i = 0; i < 3; ++i)
    {
        offsets                  [i + 1] = offsets                  [i] + counts         [i];
        microSectorOffsets       [i + 1] = microSectorOffsets       [i] + numMicroSectors[i];
        microSector32GroupOffsets[i + 1] = microSector32GroupOffsets[i] + num32Groups    [i];
    }
    
    uint baseIndex = id << 1;
    
    if (as_type<uint>(numMicroSectors.xy) != 0)
    {
        offsets_out                  [baseIndex] = offsets.xy;
        microSectorOffsets_out       [baseIndex] = microSectorOffsets.xy;
        microSector32GroupOffsets_out[baseIndex] = microSector32GroupOffsets.xy;
    }
    
    if (as_type<uint>(numMicroSectors.zw) != 0)
    {
        baseIndex += 1;
        
        offsets_out                  [baseIndex] = offsets.zw;
        microSectorOffsets_out       [baseIndex] = microSectorOffsets.zw;
        microSector32GroupOffsets_out[baseIndex] = microSector32GroupOffsets.zw;
    }
}

kernel void markSmallSector128thOffsets(device   ushort  *offsetsFinal                     [[ buffer(7) ]],
                                        device   ushort  *microSectorOffsets512th          [[ buffer(8) ]],
                                        device   ushort4 *counts512th                      [[ buffer(10) ]],
                                        device   uchar   *numMicroSectors128th             [[ buffer(14) ]],

                                        device   ushort  *offsets128th                     [[ buffer(16) ]],
                                        device   ushort  *microSectorOffsets128th          [[ buffer(17) ]],
                                        device   ushort  *microSector32GroupOffsets128th   [[ buffer(18) ]],

                                        device   ushort  *countsFinal                      [[ buffer(19) ]],
                                        device   ushort  *microSector32GroupOffsetsFinal   [[ buffer(20) ]],
                                        device   ushort  *microSectorToSmallSectorMappings [[ buffer(21) ]],
                                        device   ushort  *microSectorIDsInSmallSectors     [[ buffer(22) ]],

                                        constant ushort  *microSectorOffsets2              [[ buffer(23) ]],
                                        constant ushort  *microSector32GroupOffsets2       [[ buffer(24) ]],

                                        uint id [[ thread_position_in_grid ]])
{
    if (numMicroSectors128th[id] == 0) { return; }

    uint countIndex = id << 1;
    ushort4 counts(counts512th[countIndex].xz,
                   counts512th[countIndex + 1].xz);

    ushort3 numMicroSectors = ushort3(counts.xyz != 0);
    ushort3 num32Groups = (counts.xyz + 31) >> 5;

    ushort4 offsets                   = { offsets128th                  [id] };
    ushort4 microSectorOffsets        = { microSectorOffsets128th       [id] };
    ushort4 microSector32GroupOffsets = { microSector32GroupOffsets128th[id] };

    ushort idOfSmallSector2 = id >> 8;
    microSectorOffsets[0]        += microSectorOffsets2       [idOfSmallSector2];
    microSector32GroupOffsets[0] += microSector32GroupOffsets2[idOfSmallSector2];

    for (uchar i = 0; i < 3; ++i)
    {
        offsets                  [i + 1] = offsets                  [i] + counts         [i];
        microSectorOffsets       [i + 1] = microSectorOffsets       [i] + numMicroSectors[i];
        microSector32GroupOffsets[i + 1] = microSector32GroupOffsets[i] + num32Groups    [i];
    }

    ushort smallSectorID = id >> 7;
    ushort idInSmallSector = (127 & ushort(id)) << 2;
    uint   offsetIndex = id << 2;
    
    for (uchar i = 0; i < 4; ++i)
    {
        if (counts[i] != 0)
        {
            microSectorOffsets512th[offsetIndex + i] = microSectorOffsets[i];
            
            countsFinal                     [microSectorOffsets[i]] = counts[i];
            offsetsFinal                    [microSectorOffsets[i]] = offsets[i];
            microSector32GroupOffsetsFinal  [microSectorOffsets[i]] = microSector32GroupOffsets[i];
            microSectorToSmallSectorMappings[microSectorOffsets[i]] = smallSectorID;
            microSectorIDsInSmallSectors    [microSectorOffsets[i]] = idInSmallSector + i;
        }
    }
}

kernel void fillMicroSectors(constant ushort *smallSector256GroupOffsets [[ buffer(0) ]],
                             constant ushort *smallSectorIDBuffer_old    [[ buffer(1) ]],
                             constant ushort *smallSectorCounts_old      [[ buffer(2) ]],
                             constant uint   *smallSectorOffsets_old     [[ buffer(3) ]],
                             constant uint   *smallSectorOffsets2_new    [[ buffer(4) ]],
            
                             device   uint   *idBuffer_in                [[ buffer(5) ]],
                             device   uint   *idBuffer_out               [[ buffer(6) ]],
               
                             constant ushort *microSectorOffsetsFinal    [[ buffer(7) ]],
                             device   ushort *microSectorLocations       [[ buffer(8) ]],
                             device   void   *subsectorData              [[ buffer(9) ]],
                   
                             uint id [[ thread_position_in_grid ]])
{
    ushort smallSectorID = smallSectorIDBuffer_old[id >> 4];
    
    uint i     = (id << 4) - (uint(smallSector256GroupOffsets[smallSectorID]) << 8);
    uint i_end = min(uint(smallSectorCounts_old[smallSectorID]), i + 16);
    
    if (i >= i_end)
    {
        return;
    }
    
    uint idBufferOffset_old = smallSectorOffsets_old[smallSectorID];
    i     += idBufferOffset_old;
    i_end += idBufferOffset_old;
    
    uint smallSectorOffset2 = smallSectorOffsets2_new[smallSectorID >> 1];
    
    for (; i < i_end; ++i)
    {
        uint vertexID = idBuffer_in[i];
        uint lowMicroSectorID;
        ushort offset0;
        
        SubsectorDataHandle handle(subsectorData, i);
        Permutation permutation;
        
        handle.readCommonMetadata(lowMicroSectorID, offset0, permutation);
        
#define WRITE(a, b)                                                 \
{                                                                   \
    ushort location = microSectorLocations[lowMicroSectorID + a];   \
    ushort offset_16bit = microSectorOffsetsFinal[location] + b;    \
                                                                    \
    idBuffer_out[smallSectorOffset2 + offset_16bit] = vertexID;     \
}                                                                   \
        
        WRITE(0, offset0);
        ushort power = permutation.getPower();
        if (power == 0) { continue; }
        
        
        
        bool3 difference = permutation.getDifference();
        ushort firstOffsetIndex;
        
        if      (difference.z) { firstOffsetIndex = 1; }
        else if (difference.y) { firstOffsetIndex = 8; }
        else                   { firstOffsetIndex = 64; }
        
        WRITE(firstOffsetIndex, handle.readLowestOffset());
        if (power == 1) { continue; }
        
        
        
#define WRITE_2(a, b, c, d)                                         \
{                                                                   \
    ushort location1 = microSectorLocations[lowMicroSectorID + a];  \
    ushort location2 = microSectorLocations[lowMicroSectorID + c];  \
    ushort offset1_16bit = microSectorOffsetsFinal[location1];      \
    ushort offset2_16bit = microSectorOffsetsFinal[location2];      \
                                                                    \
    offset1_16bit += b;                                             \
    offset2_16bit += d;                                             \
    idBuffer_out[smallSectorOffset2 + offset1_16bit] = vertexID;    \
    idBuffer_out[smallSectorOffset2 + offset2_16bit] = vertexID;    \
}                                                                   \
        
        ushort secondOffsetIndex = all(difference.yz) ? 8 : 64;
        ushort thirdOffsetIndex;
        
        if (power == 2)
        {
            if      (!difference.x) { thirdOffsetIndex = 9; }
            else if (!difference.y) { thirdOffsetIndex = 65; }
            else                    { thirdOffsetIndex = 72; }
        }
        else
        {
            thirdOffsetIndex = 64;
        }
        
        ushort2 middleOffsets = handle.readMiddleOffsets();
        WRITE_2(secondOffsetIndex, middleOffsets[0],
                 thirdOffsetIndex, middleOffsets[1]);
        if (power == 2) { continue; }
        
        
        
        ushort4 upperOffsets = handle.readUpperOffsets();
        WRITE_2( 9, upperOffsets[0],
                65, upperOffsets[1]);
        WRITE_2(72, upperOffsets[2],
                73, upperOffsets[3]);
    }
}
#endif

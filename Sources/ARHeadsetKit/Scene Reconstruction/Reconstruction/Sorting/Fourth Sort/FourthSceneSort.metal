//
//  FourthSceneSort.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "FourthSceneSortTypes.metal"
#include "../../../../Other/Metal Utilities/MemoryUtilities.h"
using namespace metal;

kernel void prepareMarkNanoSectors(constant ushort *microSector32GroupOffsetsFinal [[ buffer(2) ]],
                                   constant ushort *microSectorCountsFinal         [[ buffer(3) ]],
                                   device   ushort *microSectorIDBuffer            [[ buffer(7) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    uint i     = microSector32GroupOffsetsFinal[id];
    uint i_end = i + ((microSectorCountsFinal[id] - 1) >> 5);
    
    for (; i < i_end; ++i)
    {
        microSectorIDBuffer[i] = id;
    }
    
    microSectorIDBuffer[i_end] = id;
}



inline ushort increment_vertex_count(device atomic_uint *atomicCounts, uint nanoSectorID)
{
    uint countID = nanoSectorID >> 2;
    uint power = (nanoSectorID & 3) << 3;
    
    uint offset = atomic_fetch_add_explicit(atomicCounts + countID, 1 << power, memory_order_relaxed);
    return 255 & (offset >> power);
}

kernel void markNanoSectors(constant uint        *smallSectorOffsets2              [[ buffer(0) ]],
                            constant float2x3    *smallSectorBounds                [[ buffer(1) ]],
                            
                            constant ushort      *microSector32GroupOffsetsFinal   [[ buffer(2) ]],
                            constant ushort      *microSectorCountsFinal           [[ buffer(3) ]],
                            constant ushort      *microSectorOffsets               [[ buffer(4) ]],
                            constant ushort      *microSectorToSmallSectorMappings [[ buffer(5) ]],
                            constant ushort      *microSectorIDsInSmallSectors     [[ buffer(6) ]],
                            device   ushort      *microSectorIDBuffer              [[ buffer(7) ]],
                            
                            device   uint        *idBuffer                         [[ buffer(8) ]],
                            device   float3      *worldSpacePositions              [[ buffer(9) ]],
                            
                            device   atomic_uint *atomicCounts                     [[ buffer(10) ]],
                            device   void        *subsectorData                    [[ buffer(11) ]],
                            
                            uint id [[ thread_position_in_grid ]])
{
    uint   microSectorID = microSectorIDBuffer[id >> 1];
    ushort smallSectorID = microSectorToSmallSectorMappings[microSectorID];
    
    uint i = (id << 4) - (uint(microSector32GroupOffsetsFinal[microSectorID]) << 5);
    uint i_end = min(uint(microSectorCountsFinal[microSectorID]), i + 16);
    
    if (i >= i_end)
    {
        return;
    }
    
    float2x3 bounds = smallSectorBounds[smallSectorID];
    ushort   idInSmallSector = microSectorIDsInSmallSectors[microSectorID];
    
    ushort3 subsectorIDVector;
    subsectorIDVector.xy = ushort2(idInSmallSector) >> ushort2(6, 3);
    subsectorIDVector.xy &= 7;
    subsectorIDVector.z = idInSmallSector & 7;
    
    float3 subsectorPosition = float3(subsectorIDVector) * 0.25;
    bounds += { subsectorPosition, subsectorPosition };
    
    uint idBufferOffset = smallSectorOffsets2[smallSectorID >> 1] + microSectorOffsets[microSectorID];
    i     += idBufferOffset;
    i_end += idBufferOffset;
    
    for (; i < i_end; ++i)
    {
        float3 position = worldSpacePositions[idBuffer[i]];
        float2x3 deltas = float2x3(position, position) - bounds;
        deltas *= 32;
        
        short3 upperCoords = clamp(short3(deltas[0]), 0, 7);
        short3 lowerCoords = clamp(short3(deltas[1]), 0, 7);
        
        ushort2 hashXY = ushort2(lowerCoords.xy) << ushort2(6, 3);
        uint lowNanoSectorID = (uint(microSectorID) << 9) + (hashXY[0] + hashXY[1] + lowerCoords.z);
        
#define FETCH(a) increment_vertex_count(atomicCounts, lowNanoSectorID + a);
        ushort offset0 = FETCH(0);
        
        bool3 difference = upperCoords > lowerCoords;
        ushort power = Permutation::createPower(difference);
        
        SubsectorDataHandle handle(subsectorData, i);
        handle.writeCommonMetadata(lowNanoSectorID, offset0, power, difference);
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

kernel void poolMicroSector4thCounts(device uchar  *counts512th       [[ buffer(10) ]],
                                     device ushort *counts4th         [[ buffer(12) ]],
                                     device uchar  *numNanoSectors4th [[ buffer(13) ]],
                                     device ushort *inclusions32nd    [[ buffer(19) ]],
                                     
                                     uint id [[ thread_position_in_grid ]])
{
    uint baseCountIndex = id << 3;
    
    vec<ushort, 8> combinedCounts;
    vec<ushort, 8> combinedMasks;
    
    for (ushort i = 0; i < 8; ++i)
    {
        ushort combinedCount;
        ushort combinedMask;
        
        uint4 rawCounts = reinterpret_cast<device uint4*>(counts512th)[baseCountIndex + i];
        
        for (uchar j = 0; j < 4; ++j)
        {
            ushort4 counts = ushort4(as_type<uchar4>(rawCounts[j]));
            ushort4 masks = select(ushort4(0), ushort4(1, 2, 4, 8) << j * 4, counts != 0);
            
            counts.xy += counts.zw;
            masks.xy  += masks.zw;
            
            counts[0] += counts[1];
            masks[0]  += masks[1];
            
            if (j == 0)
            {
                combinedCount = counts[0];
                combinedMask  = masks[0];
            }
            else
            {
                combinedCount += counts[0];
                combinedMask  += masks[0];
            }
        }
        
        combinedCounts[i] = combinedCount;
        combinedMasks [i] = combinedMask;
    }
    
    reinterpret_cast<device vec<ushort, 8>*>(inclusions32nd)[id] = combinedMasks;
    
    reinterpret_cast<thread uint4&>(combinedCounts).xy += as_type<uint4>(combinedCounts).zw;
    reinterpret_cast<thread uint4&>(combinedCounts)[0] += as_type<uint4>(combinedCounts)[1];
    
    ushort4 numNanoSectors = ushort4(popcount(as_type<uint4>(combinedMasks)));
    numNanoSectors.xy += numNanoSectors.zw;
    
    combinedCounts[0] += combinedCounts[1];
    numNanoSectors[0] += numNanoSectors[1];
    
    counts4th        [id] = combinedCounts[0];
    numNanoSectors4th[id] = numNanoSectors[0];
}

kernel void poolMicroSectorIndividualCounts(device ushort4 *counts4th                [[ buffer(12) ]],
                                            device uchar4  *numNanoSectors4th        [[ buffer(13) ]],
                                            
                                            device ushort  *countsIndividual         [[ buffer(14) ]],
                                            device ushort  *numNanoSectorsIndividual [[ buffer(15) ]],
                                            
                                            uint id [[ thread_position_in_grid ]])
{
    ushort4 counts = counts4th[id];
    ushort4 numNanoSectors = ushort4(numNanoSectors4th[id]);
    
    counts.xy         += counts.zw;
    numNanoSectors.xy += numNanoSectors.zw;
    
    counts[0]         += counts[1];
    numNanoSectors[0] += numNanoSectors[1];
    
    countsIndividual        [id] = counts[0];
    numNanoSectorsIndividual[id] = numNanoSectors[0];
}

kernel void poolMicroSector4to16Counts(device ushort4 *counts_in          [[ buffer(14) ]],
                                       device ushort4 *numNanoSectors_in  [[ buffer(15) ]],
                                       
                                       device ushort  *counts_out         [[ buffer(12) ]],
                                       device ushort  *numNanoSectors_out [[ buffer(13) ]],
                                       
                                       uint id [[ thread_position_in_grid ]])
{
    ushort4 counts         = counts_in        [id];
    ushort4 numNanoSectors = numNanoSectors_in[id];
    
    counts.xy         += counts.zw;
    numNanoSectors.xy += numNanoSectors.zw;
    
    counts[0]         += counts[1];
    numNanoSectors[0] += numNanoSectors[1];
    
    counts_out        [id] = counts[0];
    numNanoSectors_out[id] = numNanoSectors[0];
}

kernel void scanMicroSectors64(device ushort4 *counts16            [[ buffer(12) ]],
                               device ushort4 *numNanoSectors16    [[ buffer(13) ]],
                               
                               device ushort  *counts64            [[ buffer(14) ]],
                               device ushort  *numNanoSectors64    [[ buffer(15) ]],
                               
                               device ushort4 *offsets16           [[ buffer(16) ]],
                               device ushort4 *nanoSectorOffsets16 [[ buffer(17) ]],
                               
                               uint id [[ thread_position_in_grid ]])
{
    ushort4 counts         = counts16        [id];
    ushort4 numNanoSectors = numNanoSectors16[id];
    
    ushort4 offsets           = { 0, counts[0] };
    ushort4 nanoSectorOffsets = { 0, numNanoSectors[0] };
    
    for (uchar i = 1; i < 3; ++i)
    {
        offsets          [i + 1] = offsets          [i] + counts        [i];
        nanoSectorOffsets[i + 1] = nanoSectorOffsets[i] + numNanoSectors[i];
    }
    
    offsets16          [id] = offsets;
    nanoSectorOffsets16[id] = nanoSectorOffsets;
    
    offsets[3]           += counts[3];
    nanoSectorOffsets[3] += numNanoSectors[3];
    
    counts64        [id] = offsets[3];
    numNanoSectors64[id] = nanoSectorOffsets[3];
}



kernel void markMicroSector16to4Offsets(device ushort3 *counts_in             [[ buffer(13) ]],
                                        device ushort3 *numNanoSectors_in     [[ buffer(14) ]],
                                        
                                        device ushort  *offsets_in            [[ buffer(15) ]],
                                        device ushort  *nanoSectorOffsets_in  [[ buffer(16) ]],
                                        
                                        device ushort4 *offsets_out           [[ buffer(17) ]],
                                        device ushort4 *nanoSectorOffsets_out [[ buffer(18) ]],
                                        
                                        uint id [[ thread_position_in_grid ]])
{
    ushort3 counts         = counts_in        [id];
    ushort3 numNanoSectors = numNanoSectors_in[id];
    
    ushort4 offsets           = { offsets_in          [id] };
    ushort4 nanoSectorOffsets = { nanoSectorOffsets_in[id] };
    
    for (uchar i = 0; i < 3; ++i)
    {
        offsets          [i + 1] = offsets          [i] + counts        [i];
        nanoSectorOffsets[i + 1] = nanoSectorOffsets[i] + numNanoSectors[i];
    }
    
    offsets_out          [id] = offsets;
    nanoSectorOffsets_out[id] = nanoSectorOffsets;
}

kernel void markMicroSectorIndividualOffsets(device ushort3 *counts4th                   [[ buffer(13) ]],
                                             device uchar3  *numNanoSectors4th           [[ buffer(14) ]],
                                             
                                             device ushort4 *offsets4th                  [[ buffer(15) ]],
                                             device ushort4 *nanoSectorOffsets4th        [[ buffer(16) ]],
                                             
                                             device ushort  *offsetsIndividual           [[ buffer(17) ]],
                                             device ushort  *nanoSectorOffsetsIndividual [[ buffer(18) ]],
                                             
                                             uint id [[ thread_position_in_grid ]])
{
    ushort3 counts = counts4th[id];
    ushort3 numNanoSectors = ushort3(numNanoSectors4th[id]);
    
    ushort4 offsets           = { offsetsIndividual          [id] };
    ushort4 nanoSectorOffsets = { nanoSectorOffsetsIndividual[id] };
    
    for (uchar i = 0; i < 3; ++i)
    {
        offsets          [i + 1] = offsets          [i] + counts        [i];
        nanoSectorOffsets[i + 1] = nanoSectorOffsets[i] + numNanoSectors[i];
    }
    
    offsets4th          [id] = offsets;
    nanoSectorOffsets4th[id] = nanoSectorOffsets;
}

kernel void markMicroSector4thOffsets(device   ushort  *offsets512th         [[ buffer(9) ]],
                                      device   uchar   *counts512th          [[ buffer(11) ]],
                                      device   uint    *mappingsFinal        [[ buffer(13) ]],
                                      
                                      device   uchar   *numNanoSectors4th    [[ buffer(14) ]],
                                      device   ushort  *offsets4th           [[ buffer(15) ]],
                                      device   ushort  *nanoSectorOffsets4th [[ buffer(16) ]],
                                      constant uint    *nanoSectorOffsets64  [[ buffer(17) ]],
                                      device   ushort  *inclusions32nd       [[ buffer(19) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    if (numNanoSectors4th[id] == 0) { return; }
    
    uint baseCountIndex1 = id << 7;
    
    ushort offset = offsets4th[id];
    uint nanoSectorOffset = nanoSectorOffsets64[id >> 8] + nanoSectorOffsets4th[id];
    auto combinedMasks = reinterpret_cast<device vec<ushort, 8>*>(inclusions32nd)[id];
    
    for (ushort i = 0; i < 8; ++i)
    {
        uint baseCountIndex2 = baseCountIndex1 + (i << 4);
        ushort mask = combinedMasks[i];
        
#define MARK_OFFSETS_LOOP_BLOCK(power)              \
if (mask & (1 << (power)))                          \
{                                                   \
    uint countIndex = baseCountIndex2 + power;      \
    offsets512th [countIndex] = offset;             \
    mappingsFinal[nanoSectorOffset] = countIndex;   \
                                                    \
    offset += counts512th[countIndex];              \
    ++nanoSectorOffset;                             \
}                                                   \

#define MARK_OFFSETS_LOOP_BLOCK_4(power_start)      \
MARK_OFFSETS_LOOP_BLOCK(power_start)                \
MARK_OFFSETS_LOOP_BLOCK(power_start + 1)            \
MARK_OFFSETS_LOOP_BLOCK(power_start + 2)            \
MARK_OFFSETS_LOOP_BLOCK(power_start + 3)            \

        if (as_type<uchar2>(mask)[0])
        {
            MARK_OFFSETS_LOOP_BLOCK_4(0);
            MARK_OFFSETS_LOOP_BLOCK_4(4);
        }
        
        if (as_type<uchar2>(mask)[1])
        {
            MARK_OFFSETS_LOOP_BLOCK_4(8);
            MARK_OFFSETS_LOOP_BLOCK_4(12);
        }
    }
}

kernel void fillNanoSectors(constant uint    *smallSectorOffsets2_old          [[ buffer(0) ]],
                            
                            constant ushort  *microSector32GroupOffsetsFinal   [[ buffer(1) ]],
                            constant ushort  *microSectorCountsFinal_old       [[ buffer(2) ]],
                            constant ushort  *microSectorOffsets_old           [[ buffer(3) ]],
                            constant ushort  *microSectorToSmallSectorMappings [[ buffer(4) ]],
                            constant ushort  *microSectorIDBuffer              [[ buffer(5) ]],
                            constant uint    *microSectorOffsets64_new         [[ buffer(6) ]],
                            
                            device   uint    *idBuffer_in                      [[ buffer(7) ]],
                            device   ushort3 *idBuffer_out                     [[ buffer(8) ]],
                            
                            device   ushort  *nanoSectorOffsets                [[ buffer(9) ]],
                            device   void    *subsectorData                    [[ buffer(10) ]],
                            
                            uint id [[ thread_position_in_grid ]])
{
    uint   microSectorID = microSectorIDBuffer[id >> 1];
    ushort smallSectorID = microSectorToSmallSectorMappings[microSectorID];
    
    uint i = (id << 4) - (uint(microSector32GroupOffsetsFinal[microSectorID]) << 5);
    uint i_end = min(uint(microSectorCountsFinal_old[microSectorID]), i + 16);
    
    if (i >= i_end)
    {
        return;
    }
    
    uint idBufferOffset_old = smallSectorOffsets2_old[smallSectorID >> 1] + microSectorOffsets_old[microSectorID];
    i     += idBufferOffset_old;
    i_end += idBufferOffset_old;
    
    uint microSectorOffset = microSectorOffsets64_new[microSectorID >> 6];
    
    for (; i < i_end; ++i)
    {
        uint vertexID = idBuffer_in[i];
        uint lowNanoSectorID;
        ushort offset0;
        ushort lowestOffset;
        
        SubsectorDataHandle handle(subsectorData, i);
        Permutation permutation;
        
        handle.readCommonMetadata(lowNanoSectorID, offset0, permutation, lowestOffset);
        
#define WRITE(a, b)                                                                         \
{                                                                                           \
    uint nanoSectorID = lowNanoSectorID + a;                                                \
    ushort offset_16bit = nanoSectorOffsets[nanoSectorID] + b;                              \
                                                                                            \
    idBuffer_out[microSectorOffset + offset_16bit] = DualID::pack(vertexID, nanoSectorID);  \
}                                                                                           \
        
        WRITE(0, offset0);
        ushort power = permutation.getPower();
        if (power == 0) { continue; }
        
        
        
        bool3 difference = permutation.getDifference();
        ushort firstOffsetIndex;
        
        if      (difference.z) { firstOffsetIndex = 1; }
        else if (difference.y) { firstOffsetIndex = 8; }
        else                   { firstOffsetIndex = 64; }
        
        WRITE(firstOffsetIndex, lowestOffset);
        if (power == 1) { continue; }
        
        
        
#define WRITE_2(a, b, c, d)                                                                     \
{                                                                                               \
    uint nanoSectorID1 = lowNanoSectorID + a;                                                   \
    uint nanoSectorID2 = lowNanoSectorID + c;                                                   \
    ushort offset1_16bit = nanoSectorOffsets[nanoSectorID1];                                    \
    ushort offset2_16bit = nanoSectorOffsets[nanoSectorID2];                                    \
                                                                                                \
    offset1_16bit += b;                                                                         \
    offset2_16bit += d;                                                                         \
    idBuffer_out[microSectorOffset + offset1_16bit] = DualID::pack(vertexID, nanoSectorID1);    \
    idBuffer_out[microSectorOffset + offset2_16bit] = DualID::pack(vertexID, nanoSectorID2);    \
}                                                                                               \
        
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

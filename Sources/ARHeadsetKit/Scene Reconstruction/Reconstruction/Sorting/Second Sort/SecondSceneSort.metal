//
//  SecondSceneSort.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#include <metal_stdlib>
using namespace metal;

typedef struct {
    uchar4 lowerCounts;
    uchar4 upperCounts;
} OctantCounts_8bit;

typedef struct {
    ushort4 lowerCounts;
    ushort4 upperCounts;
} OctantCounts_16bit;

typedef struct {
    uint4 lowerMarks;
    uint4 upperMarks;
} OctantOffsets_32bit;



kernel void markLargeSectorOctants(device   uchar    *octantMarks         [[ buffer(0) ]],
                                   constant uint     &numVertexThreads    [[ buffer(1) ]],
                                   constant float2x3 &bounds              [[ buffer(2) ]],
                                   
                                   device   uint     *idBuffer            [[ buffer(3) ]],
                                   device   float3   *worldSpacePositions [[ buffer(4) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    if (id >= numVertexThreads)
    {
        if ((id & 15) == 0 || id <= numVertexThreads + 16)
        {
            octantMarks[id] = 0;
        }
        
        return;
    }
    
    auto position = worldSpacePositions[idBuffer[id]];
    ushort inclusions = 0;
    
#define SET_MARK(statement, mark1, mark2)                   \
if (statement)                                              \
{                                                           \
    if (position.z >= bounds[0].z) { inclusions |= mark1; } \
    if (position.z <  bounds[1].z) { inclusions |= mark2; } \
}                                                           \
    
    if (position.x >= bounds[0].x)
    {
        SET_MARK(position.y >= bounds[0].y, 0x80, 0x40);
        SET_MARK(position.y <  bounds[1].y, 0x20, 0x10);
    }
    
    if (position.x < bounds[1].x)
    {
        SET_MARK(position.y >= bounds[0].y, 8, 4);
        SET_MARK(position.y <  bounds[1].y, 2, 1);
    }
    
    octantMarks[id] = uchar(inclusions);
}

kernel void poolLargeSectorOctantCounts16(device uchar4            *octantMarks    [[ buffer(0) ]],
                                          device OctantCounts_8bit *octantCounts16 [[ buffer(5) ]],
                                          
                                          uint id [[ thread_position_in_grid ]])
{
    OctantCounts_8bit out{ uchar4(0), uchar4(0) };

    uint i     = id << 2;
    uint i_end = i + 4;

    for (; i < i_end; ++i)
    {
        uchar4 marks = octantMarks[i];
        if (marks[0] == 0) { break; }

        for (uchar j = 0; j < 4; ++j)
        {
            uchar4 expandedMark(marks[j]);
            uchar4 mask1 = expandedMark & uchar4(0x80, 0x40, 0x20, 0x10);
            uchar4 mask2 = expandedMark & uchar4(  8,    4,    2,    1 );

            reinterpret_cast<thread uint&>(out.lowerCounts) += as_type<uint>(uchar4(mask1 != 0));
            reinterpret_cast<thread uint&>(out.upperCounts) += as_type<uint>(uchar4(mask2 != 0));
        }
    }

    octantCounts16[id] = out;
}

kernel void poolLargeSectorOctantCounts128(device OctantCounts_8bit *octantCounts16  [[ buffer(5) ]],
                                           device OctantCounts_8bit *octantCounts128 [[ buffer(6) ]],
                                           
                                           uint id [[ thread_position_in_grid ]])
{
    OctantCounts_8bit out{ uchar4(0), uchar4(0) };
    
    uint i     = id << 3;
    uint i_end = i + 8;
    
    for (; i < i_end; ++i)
    {
        auto in = octantCounts16[i];
        
        reinterpret_cast<thread uint&>(out.lowerCounts) += as_type<uint>(in.lowerCounts);
        reinterpret_cast<thread uint&>(out.upperCounts) += as_type<uint>(in.upperCounts);
    }
    
    octantCounts128[id] = out;
}

kernel void poolLargeSectorOctantCounts2048(device OctantCounts_8bit  *octantCounts128  [[ buffer(6) ]],
                                            device OctantCounts_16bit *octantCounts2048 [[ buffer(7) ]],
                                            
                                            uint id [[ thread_position_in_grid ]])
{
    OctantCounts_16bit out{ ushort4(0), ushort4(0) };
    
    uint i     = id << 4;
    uint i_end = i + 16;
    
    for (; i < i_end; ++i)
    {
        auto in = octantCounts128[i];
        
        out.lowerCounts += ushort4(in.lowerCounts);
        out.upperCounts += ushort4(in.upperCounts);
    }
    
    octantCounts2048[id] = out;
}



kernel void markLargeSectorOctantOffsets2048(device OctantCounts_8bit   *octantCounts128 [[ buffer(6) ]],

                                             device OctantOffsets_32bit *offsets2048     [[ buffer(8) ]],
                                             device OctantOffsets_32bit *offsets128      [[ buffer(9) ]],

                                             uint id [[ thread_position_in_grid ]])
{
    auto offsets = offsets2048[id];

    uint i     = id << 4;
    uint i_end = i + 16;

    for (; i < i_end; ++i)
    {
        auto counts = octantCounts128[i];
        uint targetIndex = i << 1;

        if (as_type<uint>(counts.lowerCounts) != 0)
        {
            reinterpret_cast<device uint4*>(offsets128)[targetIndex] = offsets.lowerMarks;
            offsets.lowerMarks += uint4(counts.lowerCounts);
        }

        if (as_type<uint>(counts.upperCounts) != 0)
        {
            reinterpret_cast<device uint4*>(offsets128)[targetIndex + 1] = offsets.upperMarks;
            offsets.upperMarks += uint4(counts.upperCounts);
        }
    }
}

kernel void markLargeSectorOctantOffsets128(device OctantCounts_8bit   *octantCounts16  [[ buffer(5) ]],
                                            device OctantCounts_8bit   *octantCounts128 [[ buffer(6) ]],

                                            device OctantOffsets_32bit *offsets128      [[ buffer(9) ]],
                                            device OctantOffsets_32bit *offsets16       [[ buffer(10) ]],

                                            uint id [[ thread_position_in_grid ]])
{
    uint4 offsets[2];
    auto counts128 = octantCounts128[id];
    uint retrievedMarkIndex = id << 1;

    if (as_type<uint>(counts128.lowerCounts) != 0)
    {
        offsets[0] = reinterpret_cast<device uint4*>(offsets128)[retrievedMarkIndex];
    }

    if (as_type<uint>(counts128.upperCounts) != 0)
    {
        offsets[1] = reinterpret_cast<device uint4*>(offsets128)[retrievedMarkIndex + 1];
    }

    uint i     = id << 3;
    uint i_end = i + 8;

    for (; i < i_end; ++i)
    {
        uint2 counts = reinterpret_cast<device uint2*>(octantCounts16)[i];
        uint baseTargetIndex = i << 2;

        for (uchar j = 0; j < 2; ++j)
        {
            uint targetIndex = baseTargetIndex + (j << 1);

            if (as_type<ushort2>(counts[j])[0] != 0)
            {
                reinterpret_cast<device uint2*>(offsets16)[targetIndex] = offsets[j].xy;
                offsets[j].xy += uint2(as_type<uchar4>(counts[j]).xy);
            }

            if (as_type<ushort2>(counts[j])[1] != 0)
            {
                reinterpret_cast<device uint2*>(offsets16)[targetIndex + 1] = offsets[j].zw;
                offsets[j].zw += uint2(as_type<uchar4>(counts[j]).zw);
            }
        }
    }
}

kernel void fillLargeSectorOctants(device   vec<uchar, 16>      *octantMarks         [[ buffer(0) ]],
                                   device   uint                *idBuffer_in         [[ buffer(3) ]],
                                   device   OctantCounts_8bit   *octantCounts16      [[ buffer(5) ]],
                                   
                                   device   OctantOffsets_32bit *offsets16           [[ buffer(10) ]],
                                   constant uint                *idBufferOffsets2048 [[ buffer(11) ]],
                                   device   uint                *idBuffer_out        [[ buffer(12) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    uint4 offsets[2];
    
    auto retrievedCounts = reinterpret_cast<device uint2*>(octantCounts16)[id];
    uint retrievedMarkIndex = id << 1;
    
    for (uchar i = 0; i < 2; ++i)
    {
        uint markIndex = retrievedMarkIndex + i;
        
        if (as_type<ushort2>(retrievedCounts[i])[0] != 0)
        {
            offsets[i].xy = reinterpret_cast<device uint4*>(offsets16)[markIndex].xy;
        }
        
        if (as_type<ushort2>(retrievedCounts[i])[1] != 0)
        {
            offsets[i].zw = reinterpret_cast<device uint4*>(offsets16)[markIndex].zw;
        }
    }
    
    uint idOf2048 = id >> 7;
    uint idIn2048 = (id - (idOf2048 << 7)) << 4;
    
    auto marks = octantMarks[id];
    uint idBufferOffset = idBufferOffsets2048[idOf2048] + idIn2048;
    
    for (ushort i = 0; i < 16; ++i)
    {
        ushort mark = ushort(marks[i]);
        if (mark == 0) { return; }
        
        uint selectedID = idBuffer_in[idBufferOffset];
        ++idBufferOffset;
        
        for (uchar j = 0; j < 2; ++j)
        {
            ushort4 inclusionMask = ushort4(mark) >> (ushort4(7, 6, 5, 4) - j * 4);
            
            if (any(bool2(inclusionMask.xy & 1)))
            {
                if (inclusionMask[0] & 1) { idBuffer_out[offsets[j][0]] = selectedID; ++offsets[j][0]; }
                if (inclusionMask[1] & 1) { idBuffer_out[offsets[j][1]] = selectedID; ++offsets[j][1]; }
            }
            
            if (any(bool2(inclusionMask.zw & 1)))
            {
                if (inclusionMask[2] & 1) { idBuffer_out[offsets[j][2]] = selectedID; ++offsets[j][2]; }
                if (inclusionMask[3] & 1) { idBuffer_out[offsets[j][3]] = selectedID; ++offsets[j][3]; }
            }
        }
    }
}

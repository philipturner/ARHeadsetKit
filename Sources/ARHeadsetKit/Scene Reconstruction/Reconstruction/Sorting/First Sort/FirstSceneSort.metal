//
//  FirstSceneSort.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#include <metal_stdlib>
using namespace metal;

constant float MATCHING_TOLERANCE = 2.4 / 256.0;

typedef struct {
    uchar4 lowerCounts;
    uchar4 upperCounts;
    
    typedef struct {
        uchar4 lower;
        uchar4 upper;
    } Sizes;
    Sizes sizes;
} OctantData_8bit;

typedef struct {
    ushort4 lowerCounts;
    ushort4 upperCounts;
    
    typedef struct {
        uchar4 lower;
        uchar4 upper;
    } Sizes;
    Sizes sizes;
} OctantData_16bit;

typedef struct {
    uint4 lowerMarks;
    uint4 upperMarks;
} OctantOffsets_32bit;



kernel void markWorldOctants(device uchar2 *octantMarks         [[ buffer(0) ]],
                             device float3 *worldSpacePositions [[ buffer(1) ]],
                             
                             uint id [[ thread_position_in_grid ]])
{
    auto position = worldSpacePositions[id];
    ushort inclusions = 0;
    
#define SET_MARK(statement, mark1, mark2)                           \
if (statement)                                                      \
{                                                                   \
    if (position.z >= -MATCHING_TOLERANCE) { inclusions |= mark1; } \
    if (position.z <   MATCHING_TOLERANCE) { inclusions |= mark2; } \
}                                                                   \
    
    if (position.x >= -MATCHING_TOLERANCE)
    {
        SET_MARK(position.y >= -MATCHING_TOLERANCE, 0x80, 0x40);
        SET_MARK(position.y <   MATCHING_TOLERANCE, 0x20, 0x10);
    }
    
    if (position.x < MATCHING_TOLERANCE)
    {
        SET_MARK(position.y >= -MATCHING_TOLERANCE, 8, 4);
        SET_MARK(position.y <   MATCHING_TOLERANCE, 2, 1);
    }
    
    ushort3 position_ushort = ushort3(ceil(abs(position)));
    ushort cube_side_length = max3(position_ushort[0],
                                   position_ushort[1],
                                   position_ushort[2]);
    
    ushort power = 16 - clz(ushort(max(1, short(cube_side_length) - 1)));
    
    octantMarks[id] = uchar2(inclusions, power);
}

kernel void poolWorldOctantData16(device   uchar2          *octantMarks      [[ buffer(0) ]],
                                  constant uint            &numVertexThreads [[ buffer(2) ]],
                                  device   OctantData_8bit *octantData16     [[ buffer(3) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    uchar4 lowerCounts(0);
    uchar4 upperCounts(0);
    
    ushort4 lowerSizes(0);
    ushort4 upperSizes(0);
    
    uint i     = id << 4;
    uint i_end = min(i + 16, numVertexThreads);
    
    for (; i < i_end; ++i)
    {
        uchar2 mark = octantMarks[i];
        uchar4 expandedMark(mark[0]);
        
        uchar4 inclusions = expandedMark & uchar4{ 0x80, 0x40, 0x20, 0x10 };
        if (as_type<uint>(inclusions) != 0)
        {
            bool4 inclusionMask = inclusions != 0;
            reinterpret_cast<thread uint&>(lowerCounts) += as_type<uint>(uchar4(inclusionMask));
            lowerSizes = max(select(lowerSizes, mark[1], inclusionMask), lowerSizes);
        }
        
        inclusions = expandedMark & uchar4{ 8, 4, 2, 1 };
        if (as_type<uint>(inclusions) != 0)
        {
            bool4 inclusionMask = inclusions != 0;
            reinterpret_cast<thread uint&>(upperCounts) += as_type<uint>(uchar4(inclusionMask));
            upperSizes = max(select(upperSizes, mark[1], inclusionMask), upperSizes);
        }
    }
    
    reinterpret_cast<device uint4*>(octantData16)[id] = {
        as_type<uint>(lowerCounts),
        as_type<uint>(upperCounts),
        as_type<uint>(uchar4(lowerSizes)),
        as_type<uint>(uchar4(upperSizes))
    };
}

kernel void poolWorldOctantData256(constant uint             &numVertexThreads [[ buffer(2) ]],
                                   device   OctantData_8bit  *octantData16     [[ buffer(3) ]],
                                   device   OctantData_16bit *octantData256    [[ buffer(4) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    ushort4 lowerCounts(0);
    ushort4 upperCounts(0);
    
    ushort4 lowerSizes(0);
    ushort4 upperSizes(0);
    
    uint i     = id << 4;
    uint i_end = min(i + 15, (numVertexThreads - 1) >> 4);
    
    for (; i <= i_end; ++i)
    {
        uint4 retrievedOctantData = reinterpret_cast<device uint4*>(octantData16)[i];
        
        ushort4 selectedLowerCounts = ushort4(as_type<uchar4>(retrievedOctantData[0]));
        ushort4 selectedLowerSizes  = ushort4(as_type<uchar4>(retrievedOctantData[2]));
        
        lowerCounts += selectedLowerCounts;
        lowerSizes = max(lowerSizes, selectedLowerSizes);
        
        ushort4 selectedUpperCounts = ushort4(as_type<uchar4>(retrievedOctantData[1]));
        ushort4 selectedUpperSizes  = ushort4(as_type<uchar4>(retrievedOctantData[3]));
        
        upperCounts += selectedUpperCounts;
        upperSizes = max(upperSizes, selectedUpperSizes);
    }
    
    octantData256[id] = { lowerCounts, upperCounts, { uchar4(lowerSizes), uchar4(upperSizes) } };
}

kernel void poolWorldOctantData4096(constant uint             &numVertexThreads [[ buffer(2) ]],
                                    device   OctantData_16bit *octantData256    [[ buffer(4) ]],
                                    device   OctantData_16bit *octantData4096   [[ buffer(5) ]],
                                    
                                    uint id [[ thread_position_in_grid ]])
{
    ushort4 lowerCounts(0);
    ushort4 upperCounts(0);
    
    ushort4 lowerSizes(0);
    ushort4 upperSizes(0);
    
    uint i     = id << 4;
    uint i_end = min(i + 15, (numVertexThreads - 1) >> 8);
    
    for (; i <= i_end; ++i)
    {
        auto retrievedOctantData = octantData256[i];
        
        lowerCounts += retrievedOctantData.lowerCounts;
        upperCounts += retrievedOctantData.upperCounts;
        
        lowerSizes = max(ushort4(retrievedOctantData.sizes.lower), lowerSizes);
        upperSizes = max(ushort4(retrievedOctantData.sizes.upper), upperSizes);
    }
    
    octantData4096[id] = { lowerCounts, upperCounts, { uchar4(lowerSizes), uchar4(upperSizes) } };
}



kernel void markWorldOctantOffsets4096(constant uint                &numVertexThreads [[ buffer(2) ]],
                                       device   OctantData_16bit    *octantData256    [[ buffer(4) ]],
                                       
                                       device   OctantOffsets_32bit *offsets4096      [[ buffer(6) ]],
                                       device   OctantOffsets_32bit *offsets256       [[ buffer(7) ]],
                                       
                                       uint id [[ thread_position_in_grid ]])
{
    auto offsets = offsets4096[id];

    uint i     = id << 4;
    uint i_end = min(i + 15, (numVertexThreads - 1) >> 8);

    for (; i <= i_end; ++i)
    {
        auto retrievedOctantData = octantData256[i];
        offsets256[i] = offsets;
        
        offsets.lowerMarks += uint4(retrievedOctantData.lowerCounts);
        offsets.upperMarks += uint4(retrievedOctantData.upperCounts);
    }
}

kernel void markWorldOctantOffsets256(constant uint                &numVertexThreads [[ buffer(2) ]],
                                      device   OctantData_8bit     *octantData16     [[ buffer(3) ]],
                                      device   OctantData_16bit    *octantData256    [[ buffer(4) ]],
                                      
                                      device   OctantOffsets_32bit *offsets256       [[ buffer(7) ]],
                                      device   OctantOffsets_32bit *offsets16        [[ buffer(8) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    OctantOffsets_32bit offsets;
    auto retrievedSizes = octantData256[id].sizes;
    uint retrievedMarkIndex = id << 1;
    
    if (as_type<uint>(retrievedSizes.lower) != 0)
    {
        offsets.lowerMarks = reinterpret_cast<device uint4*>(offsets256)[retrievedMarkIndex];
    }
    
    if (as_type<uint>(retrievedSizes.upper) != 0)
    {
        offsets.upperMarks = reinterpret_cast<device uint4*>(offsets256)[retrievedMarkIndex + 1];
    }
    
    uint i     = id << 4;
    uint i_end = min(i + 15, (numVertexThreads - 1) >> 4);
    
    for (; i <= i_end; ++i)
    {
        uint2 retrievedOctantData = reinterpret_cast<device uint4*>(octantData16)[i].xy;
        uint targetMarkIndex = i << 1;
        
        if (as_type<uint>(retrievedOctantData[0]) != 0)
        {
            reinterpret_cast<device uint4*>(offsets16)[targetMarkIndex] = offsets.lowerMarks;
            offsets.lowerMarks += uint4(as_type<uchar4>(retrievedOctantData[0]));
        }
        
        if (as_type<uint>(retrievedOctantData[1]) != 0)
        {
            reinterpret_cast<device uint4*>(offsets16)[targetMarkIndex + 1] = offsets.upperMarks;
            offsets.upperMarks += uint4(as_type<uchar4>(retrievedOctantData[1]));
        }
    }
}

kernel void fillWorldOctants(device   uchar2              *octantMarks      [[ buffer(0) ]],
                             constant uint                &numVertexThreads [[ buffer(2) ]],
                             device   OctantData_8bit     *octantData16     [[ buffer(3) ]],
                             
                             device   OctantOffsets_32bit *offsets16        [[ buffer(8) ]],
                             device   uint                *idBuffer         [[ buffer(9) ]],
                             
                             uint id [[ thread_position_in_grid ]])
{
    uint4 offsets[2];
    
    auto retrievedCounts = reinterpret_cast<device uint4*>(octantData16)[id].xy;
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
    
    uint i     = id << 4;
    uint i_end = min(i + 15, numVertexThreads - 1);
    
    for (; i <= i_end; ++i)
    {
        ushort mark = ushort(octantMarks[i].x);
        
        for (uchar j = 0; j < 2; ++j)
        {
            ushort4 inclusionMask = ushort4(mark) >> (ushort4(7, 6, 5, 4) - j * 4);
            
            if (any(bool2(inclusionMask.xy & 1)))
            {
                if (inclusionMask[0] & 1) { idBuffer[offsets[j][0]] = i; ++offsets[j][0]; }
                if (inclusionMask[1] & 1) { idBuffer[offsets[j][1]] = i; ++offsets[j][1]; }
            }
            
            if (any(bool2(inclusionMask.zw & 1)))
            {
                if (inclusionMask[2] & 1) { idBuffer[offsets[j][2]] = i; ++offsets[j][2]; }
                if (inclusionMask[3] & 1) { idBuffer[offsets[j][3]] = i; ++offsets[j][3]; }
            }
        }
    }
}

//
//  SceneMeshReduction.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#include <metal_stdlib>
#include "../../../Other/Metal Utilities/MemoryUtilities.h"
using namespace metal;

constant float SMALL_SECTOR_BOUNDARY_TOLERANCE = 2.4 / 256.0;

kernel void markSubmeshVertices(device bool         *vertexMarks     [[ buffer(0) ]],
                                device packed_uint3 *triangleIndices [[ buffer(1) ]],
                                
                                uint id [[ thread_position_in_grid ]])
{
    uint3 indices = triangleIndices[id];
    
    for (uchar i = 0; i < 3; ++i)
    {
        if (vertexMarks[indices[i]] == false)
        {
            vertexMarks[indices[i]] = true;
        }
    }
}

kernel void countSubmeshVertices4to64(device uchar4 *counts_in  [[ buffer(0) ]],
                                      device uchar  *counts_out [[ buffer(1) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    uchar4 counts = counts_in[id];
    reinterpret_cast<thread ushort2&>(counts)[0] += as_type<ushort>(counts.zw);
    counts_out[id] = counts[0] + counts[1];
}

kernel void countSubmeshVertices512(device uchar4 *counts64  [[ buffer(1) ]],
                                    device ushort *counts512 [[ buffer(0) ]],
                                    
                                    uint id [[ thread_position_in_grid ]])
{
    uint i = id << 1;
    uchar4 counts = counts64[i];
    reinterpret_cast<thread ushort2&>(counts) += as_type<ushort2>(counts64[i + 1]);
    
    ushort2 intermediateSum = ushort2(counts.xy) + ushort2(counts.zw);
    counts512[id] = intermediateSum[0] + intermediateSum[1];
}

kernel void scanSubmeshVertices4096(device vec<ushort, 8> *counts512  [[ buffer(0) ]],
                                    device ushort         *counts4096 [[ buffer(1) ]],
                                    device vec<ushort, 8> *offsets512 [[ buffer(2) ]],
                                    
                                    uint id [[ thread_position_in_grid ]])
{
    auto counts = counts512[id];
    vec<ushort, 8> offsets = { 0 };
    
    for (uchar i = 0; i < 7; ++i)
    {
        offsets[i + 1] = offsets[i] + counts[i];
    }
    
    offsets512[id] = offsets;
    counts4096[id] = offsets[7] + counts[7];
}



kernel void markSubmeshVertexOffsets512(device vec<uchar,  8> *counts64   [[ buffer(0) ]],
                                        device vec<ushort, 8> *offsets64  [[ buffer(1) ]],
                                        device ushort         *offsets512 [[ buffer(2) ]],
                                        
                                        uint id [[ thread_position_in_grid ]])
{
    auto rawCounts = counts64[id];
    vec<ushort, 8> counts;
    
    for (uchar i = 0; i < 8; ++i)
    {
        counts[i] = ushort(rawCounts[i]);
    }
    
    vec<ushort, 8> offsets = { offsets512[id] };
    
    for (uchar i = 0; i < 7; ++i)
    {
        offsets[i + 1] = offsets[i] + counts[i];
    }
    
    offsets64[id] = offsets;
}

kernel void markSubmeshVertexOffsets64to16(device uchar3  *counts_in   [[ buffer(0) ]],
                                           device ushort  *offsets_in  [[ buffer(1) ]],
                                           device ushort4 *offsets_out [[ buffer(2) ]],
                                           
                                           uint id [[ thread_position_in_grid ]])
{
    ushort3 counts = ushort3(counts_in[id]);
    ushort4 offsets = { offsets_in[id] };
    
    for (uchar i = 0; i < 3; ++i)
    {
        offsets[i + 1] = offsets[i] + counts[i];
    }
    
    offsets_out[id] = offsets;
}

kernel void markSubmeshVertexOffsets4(device   uchar3 *vertexMarks   [[ buffer(0) ]],
                                      device   uint4  *vertexOffsets [[ buffer(1) ]],
                                      device   ushort *offsets4      [[ buffer(2) ]],
                                      constant uint   *offsets4096   [[ buffer(3) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    ushort3 counts = ushort3(vertexMarks[id]);
    uint4 offsets = { offsets4096[id >> 10] + offsets4[id] };
    
    for (uchar i = 0; i < 3; ++i)
    {
        offsets[i + 1] = offsets[i] + counts[i];
    }
    
    vertexOffsets[id] = offsets;
}

kernel void reduceSubmeshes_noRotation(device   uchar         *vertexMarks    [[ buffer(0) ]],
                                       device   uint          *vertexOffsets  [[ buffer(1) ]],
                                       constant uint          &numVertices    [[ buffer(2) ]],
                                       constant uint          &numTriangles   [[ buffer(3) ]],
                                       constant float3        &translation    [[ buffer(4) ]],
                                       
                                       device   packed_uint3  *inputIndices   [[ buffer(5) ]],
                                       device   packed_float3 *inputVertices  [[ buffer(6) ]],
                                       device   packed_float3 *inputNormals   [[ buffer(7) ]],
                                       
                                       device   uint3         *outputIndices  [[ buffer(8) ]],
                                       device   float3        *outputVertices [[ buffer(9) ]],
                                       device   half3         *outputNormals  [[ buffer(10) ]],
                                       
                                       uint id [[ thread_position_in_grid ]])
{
    if (id < numTriangles)
    {
        uint3 indices = inputIndices[id];
        indices.x = vertexOffsets[indices.x];
        indices.y = vertexOffsets[indices.y];
        indices.z = vertexOffsets[indices.z];
        
        outputIndices[id] = indices;
    }

    if (id >= numVertices || vertexMarks[id] == 0)
    {
        return;
    }
    
    uint offset = vertexOffsets[id];
    outputVertices[offset] = inputVertices[id] + translation;
    outputNormals [offset] = half3(inputNormals[id]);
}

// When creating scene color reconstruction, the transformation of
// submeshes into a common coordinate system included a rotation transform.
// In order to maximize the chance of duplicate vertices being correctly
// identified, double-precision emulation was used to maximize precision
// of transformed vertices.
//
// Now, coordinate system transformation now retains the original
// orientation, as each submesh covers the exact same volume footprint
// as a small sector, and retaining orientation allows triangles
// to be culled by small sector before being culled by a projection transform.
//
// This shader had to be compiled separately (in ReduceSubmeshes.metallib)
// because fast math had to be disabled, as it reassociates floating-point
// operations necessary for emulating double-precision arithmetic, but
// must be activated for all other shaders in this framework.
//
// Although this shader is no longer necessary, it is still included as an
// example of how to emulate double-precision arithmetic in Metal Shading Language.

#if 0

kernel void reduceSubmeshes(device   uchar         *vertexMarks    [[ buffer(0) ]],
                            device   uint          *vertexOffsets  [[ buffer(1) ]],
                            constant uint          &numVertices    [[ buffer(2) ]],
                            constant uint          &numTriangles   [[ buffer(3) ]],
                            constant float4x3      &transform      [[ buffer(4) ]],

                            device   packed_uint3  *inputIndices   [[ buffer(5) ]],
                            device   packed_float3 *inputVertices  [[ buffer(6) ]],
                            device   packed_float3 *inputNormals   [[ buffer(7) ]],

                            device   uint3         *outputIndices  [[ buffer(8) ]],
                            device   float3        *outputVertices [[ buffer(9) ]],
                            device   half3         *outputNormals  [[ buffer(10) ]],

                            uint id [[ thread_position_in_grid ]])
{
    if (id < numTriangles)
    {
        uint3 indices = inputIndices[id];
        indices.x = vertexOffsets[indices.x];
        indices.y = vertexOffsets[indices.y];
        indices.z = vertexOffsets[indices.z];
        
        outputIndices[id] = indices;
    }

    if (id >= numVertices || vertexMarks[id] == 0)
    {
        return;
    }

    float3 position = inputVertices[id];
    float3 normal   = inputNormals [id];
    
    float x_hi = half(position.x);
    float y_hi = half(position.y);
    float z_hi = half(position.z);
    
    float x_lo = position.x - x_hi;
    float y_lo = position.y - y_hi;
    float z_lo = position.z - z_hi;

    float  sum_hi,  sum_lo, a_v, factor;
    float temp_hi, temp_lo, b_v, a_hi;
    
    float normal_temp;

#define ADD_BLOCK(coord_lo)                         \
temp_hi = a_hi + sum_hi;                            \
b_v = temp_hi - a_hi;                               \
a_v = temp_hi - b_v;                                \
temp_lo = (a_hi - a_v) + (sum_hi - b_v);            \
temp_lo = fma(coord_lo, factor, temp_lo) + sum_lo;  \

#define RESULT_BLOCK                                \
sum_hi = temp_lo + temp_hi;                         \
sum_lo = temp_lo - (sum_hi - temp_hi);              \

#define REDUCE_SUBMESHES_LOOP_BLOCK(i)              \
factor = transform.columns[3][i];                   \
sum_hi = half(factor);                              \
sum_lo = factor - sum_hi;                           \
                                                    \
factor = transform.columns[2][i];                   \
normal_temp = normal[i] * factor;                   \
a_hi = z_hi * factor;                               \
ADD_BLOCK(z_lo)                                     \
RESULT_BLOCK                                        \
                                                    \
factor = transform.columns[1][i];                   \
normal_temp = fma(normal[i], factor, normal_temp);  \
a_hi = y_hi * factor;                               \
ADD_BLOCK(y_lo);                                    \
RESULT_BLOCK                                        \
                                                    \
factor = transform.columns[0][i];                   \
normal[i] = fma(normal[i], factor, normal_temp);    \
a_hi = x_hi * factor;                               \
ADD_BLOCK(x_lo);                                    \
                                                    \
position[i] = temp_lo + temp_hi;                    \

    REDUCE_SUBMESHES_LOOP_BLOCK(0);
    REDUCE_SUBMESHES_LOOP_BLOCK(1);
    REDUCE_SUBMESHES_LOOP_BLOCK(2);

    uint offset = vertexOffsets[id];
    outputVertices[offset] = position;
    outputNormals [offset] = half3(normal);
}

#endif



inline uint makeHash(float3 coords)
{
    uint hashX = as_type<uint>(int(coords.x)) & 2047;
    uint hashY = as_type<uint>(int(coords.y)) & 2047;
    uint hashZ = as_type<uint>(int(coords.z)) & 1023;
    
    return (hashX << 21) | (hashY << 10) | (hashZ);
}

#define ASSIGN_VERTEX_SECTOR_IDS_PARAMS(SectorID)                   \
device   float3   *reducedVertices               [[ buffer(1) ]],   \
                                                                    \
constant uchar    &numSmallSectorsMinus1         [[ buffer(2) ]],   \
constant uint     *smallSectorSortedHashes       [[ buffer(3) ]],   \
constant ushort   *smallSectorSortedHashMappings [[ buffer(4) ]],   \
                                                                    \
device   SectorID *vertexIndividualSectorIDs     [[ buffer(5) ]],   \
                                                                    \
uint id [[ thread_position_in_grid ]]                               \

template <typename T>
void assignVertexSectorIDsCommon(ASSIGN_VERTEX_SECTOR_IDS_PARAMS(T))
{
    float3 position = reducedVertices[id];
    
    for (uchar i = 0; i < 3; ++i)
    {
        position[i] *= 0.5;
        
        if (abs(fract(position[i]) - 0.5) > 0.5 - SMALL_SECTOR_BOUNDARY_TOLERANCE / 2)
        {
            vertexIndividualSectorIDs[id] = numeric_limits<T>::max();
            return;
        }
    }
    
    uint smallSectorHash = makeHash(floor(position));
    
    ushort hashLocation = BinarySearch::binarySearch(smallSectorHash, smallSectorSortedHashes,
                                                     numSmallSectorsMinus1);
    
    vertexIndividualSectorIDs[id] = smallSectorSortedHashMappings[hashLocation];
}

#define CALL_ASSIGN_VERTEX_SECTOR_IDS_COMMON                \
assignVertexSectorIDsCommon(reducedVertices,                \
                            numSmallSectorsMinus1,          \
                            smallSectorSortedHashes,        \
                            smallSectorSortedHashMappings,  \
                            vertexIndividualSectorIDs, id); \

kernel void assignVertexSectorIDs_8bit (ASSIGN_VERTEX_SECTOR_IDS_PARAMS(uchar))  { CALL_ASSIGN_VERTEX_SECTOR_IDS_COMMON }
kernel void assignVertexSectorIDs_16bit(ASSIGN_VERTEX_SECTOR_IDS_PARAMS(ushort)) { CALL_ASSIGN_VERTEX_SECTOR_IDS_COMMON }



#define POOL_VERTEX_SECTOR_GROUP_IDS_PARAMS(SectorID)               \
device   SectorID    *vertexIndividualSectorIDs [[ buffer(5) ]],    \
device   SectorID    *vertexGroupSectorIDs      [[ buffer(6) ]],    \
device   atomic_uint *vertexGroupMasks          [[ buffer(7) ]],    \
                                                                    \
constant uint        &preCullVertexCount        [[ buffer(8) ]],    \
                                                                    \
uint id [[ thread_position_in_grid ]]                               \

template <typename T>
void poolVertexGroupSectorIDsCommon(POOL_VERTEX_SECTOR_GROUP_IDS_PARAMS(T))
{
    uint i = id << 3;
    T    groupSectorID = vertexIndividualSectorIDs[i];
    bool verticesHaveSameSector;
    
    if (groupSectorID == numeric_limits<T>::max())
    {
        verticesHaveSameSector = false;
    }
    else
    {
        ++i;

        if (i + 7 > preCullVertexCount)
        {
            verticesHaveSameSector = true;
            
            for (; i < preCullVertexCount; ++i)
            {
                T currentSectorID = vertexIndividualSectorIDs[i];

                if (currentSectorID != groupSectorID)
                {
                    verticesHaveSameSector = false;
                    break;
                }
            }
        }
        else
        {
            vec<T, 3> sectorIDs1 = {
                vertexIndividualSectorIDs[i],
                vertexIndividualSectorIDs[i + 1],
                vertexIndividualSectorIDs[i + 2]
            };

            if (any(sectorIDs1 != groupSectorID))
            {
                verticesHaveSameSector = false;
            }
            else
            {
                vec<T, 4> sectorIDs2 = {
                    vertexIndividualSectorIDs[i + 3],
                    vertexIndividualSectorIDs[i + 4],
                    vertexIndividualSectorIDs[i + 5],
                    vertexIndividualSectorIDs[i + 6]
                };
                
                verticesHaveSameSector = all(sectorIDs2 == groupSectorID);
            }
        }
    }
    
    if (verticesHaveSameSector)
    {
        vertexGroupSectorIDs[id] = groupSectorID;
    }
    else
    {
        uint countID = id >> 5;
        uchar power = id & 31;
        
        atomic_fetch_or_explicit(vertexGroupMasks + countID, uint(1) << power, memory_order_relaxed);
    }
}

#define CALL_POOL_VERTEX_GROUP_SECTOR_IDS_COMMON            \
poolVertexGroupSectorIDsCommon(vertexIndividualSectorIDs,   \
                               vertexGroupSectorIDs,        \
                               vertexGroupMasks,            \
                               preCullVertexCount, id);     \

kernel void poolVertexGroupSectorIDs_8bit (POOL_VERTEX_SECTOR_GROUP_IDS_PARAMS(uchar))  { CALL_POOL_VERTEX_GROUP_SECTOR_IDS_COMMON }
kernel void poolVertexGroupSectorIDs_16bit(POOL_VERTEX_SECTOR_GROUP_IDS_PARAMS(ushort)) { CALL_POOL_VERTEX_GROUP_SECTOR_IDS_COMMON }



#define ASSIGN_TRIANGLE_SECTOR_IDS_PARAMS(SectorID)                 \
device   uint3    *reducedIndices                [[ buffer(0) ]],   \
device   float3   *reducedVertices               [[ buffer(1) ]],   \
                                                                    \
constant uchar    &numSmallSectorsMinus1         [[ buffer(2) ]],   \
constant uint     *smallSectorSortedHashes       [[ buffer(3) ]],   \
constant ushort   *smallSectorSortedHashMappings [[ buffer(4) ]],   \
                                                                    \
device   SectorID *triangleIndividualSectorIDs   [[ buffer(5) ]],   \
                                                                    \
uint id [[ thread_position_in_grid ]]                               \

template <typename T>
void assignTriangleSectorIDsCommon(ASSIGN_TRIANGLE_SECTOR_IDS_PARAMS(T))
{
    uint3 indices = reducedIndices[id];
    
    float3 vertices[3];
    
    for (uchar i = 0; i < 3; ++i)
    {
        vertices[i] = reducedVertices[indices[i]];
    }
    
    float3 center = (vertices[0] + vertices[1] + vertices[2]) * (1.0 / 3);
    
    uint smallSectorHash = makeHash(floor(center * 0.5));
    
    ushort hashLocation = BinarySearch::binarySearch(smallSectorHash, smallSectorSortedHashes,
                                                     numSmallSectorsMinus1);
    
    triangleIndividualSectorIDs[id] = smallSectorSortedHashMappings[hashLocation];
}

#define CALL_ASSIGN_TRIANGLE_SECTOR_IDS_COMMON                  \
assignTriangleSectorIDsCommon(reducedIndices, reducedVertices,  \
                              numSmallSectorsMinus1,            \
                              smallSectorSortedHashes,          \
                              smallSectorSortedHashMappings,    \
                              triangleIndividualSectorIDs, id); \

kernel void assignTriangleSectorIDs_8bit (ASSIGN_TRIANGLE_SECTOR_IDS_PARAMS(uchar))  { CALL_ASSIGN_TRIANGLE_SECTOR_IDS_COMMON }
kernel void assignTriangleSectorIDs_16bit(ASSIGN_TRIANGLE_SECTOR_IDS_PARAMS(ushort)) { CALL_ASSIGN_TRIANGLE_SECTOR_IDS_COMMON }



#define POOL_TRIANGLE_GROUP_SECTOR_IDS_COMMON(SectorID)             \
device   SectorID    *triangleIndividualSectorIDs [[ buffer(5) ]],  \
device   SectorID    *triangleGroupSectorIDs      [[ buffer(6) ]],  \
device   atomic_uint *triangleGroupMasks          [[ buffer(7) ]],  \
                                                                    \
constant uint        &preCullTriangleCount        [[ buffer(8) ]],  \
                                                                    \
uint id [[ thread_position_in_grid ]]                               \

template <typename T>
void poolTriangleGroupSectorIDsCommon(POOL_TRIANGLE_GROUP_SECTOR_IDS_COMMON(T))
{
    uint i = id << 3;
    T    groupSectorID = triangleIndividualSectorIDs[i];
    bool trianglesHaveSameSector;
    
    ++i;
    
    if (i + 7 > preCullTriangleCount)
    {
        trianglesHaveSameSector = true;
        
        for (; i < preCullTriangleCount; ++i)
        {
            T currentSectorID = triangleIndividualSectorIDs[i];
            
            if (currentSectorID != groupSectorID)
            {
                trianglesHaveSameSector = false;
                break;
            }
        }
    }
    else
    {
        vec<T, 3> sectorIDs1 = {
            triangleIndividualSectorIDs[i],
            triangleIndividualSectorIDs[i + 1],
            triangleIndividualSectorIDs[i + 2]
        };

        if (any(sectorIDs1 != groupSectorID))
        {
            trianglesHaveSameSector = false;
        }
        else
        {
            vec<T, 4> sectorIDs2 = {
                triangleIndividualSectorIDs[i + 3],
                triangleIndividualSectorIDs[i + 4],
                triangleIndividualSectorIDs[i + 5],
                triangleIndividualSectorIDs[i + 6]
            };

            trianglesHaveSameSector = all(sectorIDs2 == groupSectorID);
        }
    }
    
    if (trianglesHaveSameSector)
    {
        triangleGroupSectorIDs[id] = groupSectorID;
    }
    else
    {
        uint countID = id >> 5;
        uchar power = id & 31;
        
        atomic_fetch_or_explicit(triangleGroupMasks + countID, uint(1) << power, memory_order_relaxed);
    }
}

#define CALL_POOL_TRIANGLE_GROUP_SECTOR_IDS_COMMON              \
poolTriangleGroupSectorIDsCommon(triangleIndividualSectorIDs,   \
                                 triangleGroupSectorIDs,        \
                                 triangleGroupMasks,            \
                                 preCullTriangleCount, id);     \

kernel void poolTriangleGroupSectorIDs_8bit (POOL_TRIANGLE_GROUP_SECTOR_IDS_COMMON(uchar))  { CALL_POOL_TRIANGLE_GROUP_SECTOR_IDS_COMMON }
kernel void poolTriangleGroupSectorIDs_16bit(POOL_TRIANGLE_GROUP_SECTOR_IDS_COMMON(ushort)) { CALL_POOL_TRIANGLE_GROUP_SECTOR_IDS_COMMON }

//
//  SceneCulling.metal.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4x4 viewProjectionTransform;
    float4x4 cameraProjectionTransform;
} VertexUniforms;

typedef struct {
    float4x4 leftProjectionTransform;
} VRVertexUniforms;

template <typename T>
inline bool groupIsExcluded(uint id,
                            
                            constant uchar *groupMasks,
                            device   T     *groupSectorIDs,
                            constant bool  *sectorsAreIncluded)
{
    uchar groupMask = groupMasks[id >> 3];
    bool  groupHasSameSector = ((1 << (id & 7)) & groupMask) == 0;
    
    if (groupHasSameSector)
    {
        T groupSectorID = groupSectorIDs[id];
        
        if (!sectorsAreIncluded[groupSectorID])
        {
            
            return true;
        }
    }
    
    return false;
}



#define MARK_VERTEX_CULLS_PARAMS(SectorID)                      \
constant VertexUniforms &vertexUniforms       [[ buffer(0) ]],  \
constant uint           &preCullVertexCount   [[ buffer(1) ]],  \
device   float3         *reducedVertices      [[ buffer(3) ]],  \
                                                                \
device   uchar2         *vertexInclusionData  [[ buffer(5) ]],  \
constant uchar          *vertexGroupMasks     [[ buffer(6) ]],  \
device   SectorID       *vertexGroupSectorIDs [[ buffer(7) ]],  \
constant bool           *sectorsAreIncluded   [[ buffer(8) ]],  \
                                                                \
uint id [[ thread_position_in_grid ]]                           \

template <typename T>
void markVertexCullsCommon(MARK_VERTEX_CULLS_PARAMS(T))
{
    if (groupIsExcluded(id, vertexGroupMasks, vertexGroupSectorIDs, sectorsAreIncluded))
    {
        return;
    }
    
    uint i     = id << 3;
    uint i_end = min(i + 8, preCullVertexCount);
    
    for (; i < i_end; ++i)
    {
        float3 position = reducedVertices[i];
        
        half4 pos1 = half4(  vertexUniforms.viewProjectionTransform * float4(position, 1));
        half4 pos2 = half4(vertexUniforms.cameraProjectionTransform * float4(position, 1));
        
        bool4 comparisonsZ = half4(pos1.z, pos2.z, -pos1.z, -pos2.z)
                           > half4(pos1.w, pos2.w,       0,       0);
        
        uchar4 out = select(0, uchar4(8, 8, 4, 4), comparisonsZ);
        
        if (any(abs(pos2.xy) > abs(pos2.w)) ||
            any(abs(pos1.xy) > abs(pos1.w)))
        {
            bool4 comparisonsX = half4(pos1.x, pos2.x, -pos1.x, -pos2.x)
                               > half4(pos1.w, pos2.w,  pos1.w,  pos2.w);
            bool4 comparisonsY = half4(pos1.y, pos2.y, -pos1.y, -pos2.y)
                               > half4(pos1.w, pos2.w,  pos1.w,  pos2.w);
            
            out |= select(0, uchar4(128, 128, 64, 64), comparisonsX);
            out |= select(0, uchar4( 32,  32, 16, 16), comparisonsY);
        }
        
        vertexInclusionData[i] = out.xy | out.zw;
    }
}

#define CALL_MARK_VERTEX_CULLS_COMMON           \
markVertexCullsCommon(vertexUniforms,           \
                      preCullVertexCount,       \
                      reducedVertices,          \
                                                \
                      vertexInclusionData,      \
                      vertexGroupMasks,         \
                      vertexGroupSectorIDs,     \
                      sectorsAreIncluded, id);  \

kernel void markVertexCulls_8bit (MARK_VERTEX_CULLS_PARAMS(uchar))  { CALL_MARK_VERTEX_CULLS_COMMON }
kernel void markVertexCulls_16bit(MARK_VERTEX_CULLS_PARAMS(ushort)) { CALL_MARK_VERTEX_CULLS_COMMON }



#define MARK_TRIANGLE_CULLS_PARAMS(SectorID)                \
constant uint     &preCullTriangleCount   [[ buffer(2) ]],  \
device   uint3    *reducedIndices         [[ buffer(4) ]],  \
                                                            \
device   uchar2   *vertexInclusionData    [[ buffer(5) ]],  \
constant uchar    *triangleGroupMasks     [[ buffer(6) ]],  \
device   SectorID *triangleGroupSectorIDs [[ buffer(7) ]],  \
constant bool     *sectorsAreIncluded     [[ buffer(8) ]],  \
                                                            \
device   bool2    *vertexMarks            [[ buffer(9) ]],  \
device   uchar2   *triangleInclusions8    [[ buffer(11) ]], \
                                                            \
uint id [[ thread_position_in_grid ]]                       \

template <typename T>
void markTriangleCullsCommon(MARK_TRIANGLE_CULLS_PARAMS(T))
{
    if (groupIsExcluded(id, triangleGroupMasks, triangleGroupSectorIDs, sectorsAreIncluded))
    {
        triangleInclusions8[id] = uchar2(0);
        return;
    }
    
    uint   i     = id << 3;
    ushort j_end = min(uint(8), preCullTriangleCount - i);
    
    auto selectedReducedIndices = reducedIndices + i;
    ushort2 mask = { 0, 0 };
    
    ushort j = 0;
    
    for (; j < j_end; ++j)
    {
        uint3 indices = selectedReducedIndices[j];
        bool2 shouldMarkInclusions;
        
        uchar2 retrievedInclusionData = vertexInclusionData[indices[0]];
        
        if (all(retrievedInclusionData == 0))
        {
            shouldMarkInclusions = true;
        }
        else
        {
            uchar2 combinedInclusionMask = retrievedInclusionData & vertexInclusionData[indices[1]]
                                                                  & vertexInclusionData[indices[2]];
            shouldMarkInclusions = combinedInclusionMask == 0;
        }
        
        mask |= select(ushort2(0), ushort(1) << j, shouldMarkInclusions);
        
        for (uchar k = 0; k < 3; ++k)
        {
            auto markPointer = vertexMarks + indices[k];
            bool2 shouldWrite = shouldMarkInclusions && !*markPointer;
            
            for (uchar l = 0; l < 2; ++l)
            {
                if (shouldWrite[l])
                {
                    reinterpret_cast<device bool*>(markPointer)[l] = true;
                }
            }
        }
    }
    
    triangleInclusions8[id] = uchar2(mask);
}

#define CALL_TRIANGLE_CULLS_COMMON                  \
markTriangleCullsCommon(preCullTriangleCount,       \
                        reducedIndices,             \
                                                    \
                        vertexInclusionData,        \
                        triangleGroupMasks,         \
                        triangleGroupSectorIDs,     \
                        sectorsAreIncluded,         \
                                                    \
                        vertexMarks,                \
                        triangleInclusions8, id);   \

kernel void markTriangleCulls_8bit (MARK_TRIANGLE_CULLS_PARAMS(uchar))  { CALL_TRIANGLE_CULLS_COMMON }
kernel void markTriangleCulls_16bit(MARK_TRIANGLE_CULLS_PARAMS(ushort)) { CALL_TRIANGLE_CULLS_COMMON }



kernel void countCullMarks8(constant uint   &preCullVertexCount   [[ buffer(1) ]],
                            constant uint   &preCullTriangleCount [[ buffer(2) ]],
                            
                            device   uint4  *vertexMarks          [[ buffer(9) ]],
                            device   uchar2 *vertexInclusions8    [[ buffer(10) ]],
                            device   uchar2 *triangleInclusions8  [[ buffer(11) ]],
                            device   uchar4 *counts8              [[ buffer(12) ]],
                            
                            uint id [[ thread_position_in_grid ]])
{
    uchar4 output;
    
    if (id <= (preCullVertexCount - 1) >> 3)
    {
        uint4 marks = vertexMarks[id];
        
        ushort4 tempMarks1 = as_type<ushort4>(marks.xy) << ushort4(0, 1, 2, 3);
        ushort4 tempMarks2 = as_type<ushort4>(marks.zw) << ushort4(4, 5, 6, 7);
        
        tempMarks1    |= tempMarks2;
        tempMarks1.xy |= tempMarks1.zw;
        tempMarks1.x  |= tempMarks1.y;
        
        uchar2 finalMarks = as_type<uchar2>(tempMarks1.x);
        
        output.xy = popcount(finalMarks);
        
        vertexInclusions8[id] = finalMarks;
    }
    else
    {
        output.xy = uchar2(0);
    }
    
    output.zw = popcount(triangleInclusions8[id]);
    
    counts8[id] = output;
}

kernel void countCullMarks32to128(device uint4  *counts_in  [[ buffer(12) ]],
                                  device uchar4 *counts_out [[ buffer(13) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    uint4 counts = counts_in[id];
    counts.xy += counts.zw;
    counts[0] += counts[1];
    
    counts_out[id] = as_type<uchar4>(counts[0]);
}

kernel void countCullMarks512(device uint4   *counts128 [[ buffer(13) ]],
                              device ushort4 *counts512 [[ buffer(14) ]],
                              
                              uint id [[ thread_position_in_grid ]])
{
    uint4 counts = counts128[id];
    
    ushort4 counts0 = ushort4(as_type<uchar4>(counts[0])) + ushort4(as_type<uchar4>(counts[1]));
    ushort4 counts1 = ushort4(as_type<uchar4>(counts[2])) + ushort4(as_type<uchar4>(counts[3]));
    
    counts512[id] = counts0 + counts1;
}

kernel void countCullMarks2048to8192(device ulong4  *counts_in  [[ buffer(14) ]],
                                     device ushort4 *counts_out [[ buffer(15) ]],
                                     
                                     uint id [[ thread_position_in_grid ]])
{
    ulong4 counts = counts_in[id];
    counts.xy += counts.zw;
    counts[0] += counts[1];
    
    counts_out[id] = as_type<ushort4>(counts[0]);
}



typedef struct {
    MTLDrawPrimitivesIndirectArguments       triangleVertexCount;
    MTLDrawPrimitivesIndirectArguments       occlusionTriangleInstanceCount;
    MTLDispatchThreadgroupsIndirectArguments occlusionTriangleCount;
} IndirectArguments;

kernel void scanSceneCulls(constant uint              &preCullVertexCount   [[ buffer(1) ]],
                           constant uint              &preCullTriangleCount [[ buffer(2) ]],
                           
                           device   ushort4           *counts8192           [[ buffer(15) ]],
                           device   uint4             *offsets8192          [[ buffer(16) ]],
                           device   IndirectArguments &indirectArguments    [[ buffer(17) ]])
{
    ushort i = 0;
    ushort2 i_ends = ushort2((uint2(preCullVertexCount, preCullTriangleCount) + 8191) >> 13);
    
    uint4 total_offsets = uint4(0);
    
    while (i < i_ends.x)
    {
        offsets8192[i] = total_offsets;
        total_offsets += uint4(counts8192[i]);
        
        ++i;
    }
    
    for (; i < i_ends.y; ++i)
    {
        offsets8192[i].zw = total_offsets.zw;
        total_offsets.zw += uint2(counts8192[i].zw);
    }
    
    indirectArguments.triangleVertexCount.instanceCount = total_offsets[2];
    indirectArguments.occlusionTriangleInstanceCount.instanceCount  = total_offsets[3];
    indirectArguments.occlusionTriangleCount.threadgroupsPerGrid[0] = total_offsets[3];
}

kernel void markCullOffsets8192to2048(device uint4  *offsets_in  [[ buffer(16) ]],
                                      device uint4  *offsets_out [[ buffer(15) ]],
                                      device ulong3 *counts_in   [[ buffer(14) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    ulong3 counts = counts_in [id];
    uint4 offsets = offsets_in[id];
    
    uint i = id << 2;
    
    for (uchar j = 0; j < 3; ++j)
    {
        offsets_out[i] = offsets;
        offsets += uint4(as_type<ushort4>(counts[j]));
        ++i;
    }
    
    offsets_out[i] = offsets;
}

kernel void markCullOffsets512to32(device uint4 *offsets_in  [[ buffer(15) ]],
                                   device uint4 *offsets_out [[ buffer(14) ]],
                                   device uint3 *counts_in   [[ buffer(13) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    uint3 counts  = counts_in [id];
    uint4 offsets = offsets_in[id];
    
    uint i = id << 2;
    
    for (uchar j = 0; j < 3; ++j)
    {
        offsets_out[i] = offsets;
        offsets += uint4(as_type<uchar4>(counts[j]));
        ++i;
    }
    
    offsets_out[i] = offsets;
}



#define CONDENSE_GEOMETRY_REPEAT(funcName)  \
funcName(0);                                \
funcName(1);                                \
funcName(2);                                \
funcName(3);                                \
funcName(4);                                \
funcName(5);                                \
funcName(6);                                \
funcName(7);                                \



#define CONDENSE_VERTICES_PARAMS(Vertex)                \
device float3 *reducedVertices   [[ buffer(3) ]],       \
device uint   *renderOffsets     [[ buffer(5) ]],       \
device uint   *occlusionOffsets  [[ buffer(9) ]],       \
                                                        \
device Vertex *renderVertices    [[ buffer(6) ]],       \
device float4 *occlusionVertices [[ buffer(7) ]],       \
device float2 *videoFrameCoords  [[ buffer(8) ]],       \
                                                        \
device ushort *vertexInclusions8 [[ buffer(10) ]],      \
device uint4  *offsets8          [[ buffer(14) ]],      \
                                                        \
uint id [[ thread_position_in_grid ]]                   \

#define CONDENSE_TRIANGLES_PARAMS                       \
device uint   *renderTriangleIDs    [[ buffer(0) ]],    \
device uint   *occlusionTriangleIDs [[ buffer(1) ]],    \
                                                        \
device ushort *triangleInclusions8  [[ buffer(11) ]],   \
device uint4  *offsets8             [[ buffer(14) ]],   \
                                                        \
uint id [[ thread_position_in_grid ]]                   \



#define PREPARE_CONDENSE_VERTICES       \
ushort mask = vertexInclusions8[id];    \
if (mask == 0) { return; }              \
                                        \
uint2 offsets = offsets8[id].xy;        \
uint baseVertexID = id << 3;            \

template <typename VertexUniforms, typename Vertex, Vertex getVertex(VertexUniforms uniforms, float4 position)>
void condenseVerticesCommon(VertexUniforms vertexUniforms, float4x4 cameraProjectionTransform,
                            CONDENSE_VERTICES_PARAMS(Vertex),
                            thread uint2 &offsets, ushort mask, ushort i)
{
    if (mask & (257 << i))
    {
        uint vertexID = id + i;
        float4 position(reducedVertices[vertexID], 1);
        
        float4 cameraClipPosition = cameraProjectionTransform * position;
        
        if (mask & (1 << i))
        {
            float multiplier = fast::divide(0.5, cameraClipPosition.w);
            videoFrameCoords[offsets[0]] = fma(cameraClipPosition.xy, float2(multiplier, -multiplier), float2(0.5));
            renderVertices  [offsets[0]] = getVertex(vertexUniforms, position);
            
            renderOffsets[vertexID] = offsets[0];
            ++offsets[0];
        }
        
        if (mask & (256 << i))
        {
            occlusionVertices[offsets[1]] = cameraClipPosition;
            
            occlusionOffsets[vertexID] = offsets[1];
            ++offsets[1];
        }
    }
}

#define CALL_CONDENSE_VERTICES_COMMON(a, b, c, d, e, i)                                 \
condenseVerticesCommon<a, b, c>(d, e, reducedVertices, renderOffsets, occlusionOffsets, \
                                renderVertices, occlusionVertices, videoFrameCoords,    \
                                vertexInclusions8, offsets8,                            \
                                baseVertexID, offsets, mask, i);                        \



inline float4 getVertex(VertexUniforms uniforms, float4 position)
{
    return uniforms.viewProjectionTransform * position;
}

kernel void condenseVertices(constant VertexUniforms &vertexUniforms [[ buffer(0) ]],
                             CONDENSE_VERTICES_PARAMS(float4))
{
    PREPARE_CONDENSE_VERTICES;
    
#define CONDENSE_VERTICES_BLOCK(i)                                          \
CALL_CONDENSE_VERTICES_COMMON(VertexUniforms, float4, getVertex,            \
                              vertexUniforms,                               \
                              vertexUniforms.cameraProjectionTransform, i); \
    
    CONDENSE_GEOMETRY_REPEAT(CONDENSE_VERTICES_BLOCK);
}



inline float4 getVRVertex(VRVertexUniforms uniforms, float4 position)
{
    return uniforms.leftProjectionTransform * position;
}

kernel void condenseVRVertices(constant VertexUniforms   &vertexUniforms      [[ buffer(0) ]],
                               constant VRVertexUniforms &headsetModeUniforms [[ buffer(1) ]],
                               CONDENSE_VERTICES_PARAMS(float4))
{
    PREPARE_CONDENSE_VERTICES;
    
#define CONDENSE_VR_VERTICES_BLOCK(i)                                                       \
CALL_CONDENSE_VERTICES_COMMON(VRVertexUniforms, float4, getVRVertex, headsetModeUniforms,   \
                              vertexUniforms.cameraProjectionTransform, i);                 \

    CONDENSE_GEOMETRY_REPEAT(CONDENSE_VR_VERTICES_BLOCK);
}



#define PREPARE_CONDENSE_TRIANGLES      \
ushort mask = triangleInclusions8[id];  \
if (mask == 0) { return; }              \
                                        \
uint2 offsets = offsets8[id].zw;        \
uint baseTriangleID = id << 3;          \

template <bool doingColorUpdate>
void condenseTrianglesCommon(CONDENSE_TRIANGLES_PARAMS,
                             thread uint2 &offsets, ushort mask, ushort i)
{
    if (mask & (257 << i))
    {
        uint triangleID = id + i;
        
        if (mask & (1 << i))
        {
            uint cameraVisibilityMask = select(uint(1 << 31), uint(0), mask & (256 << i));
            renderTriangleIDs[offsets[0]] = triangleID | cameraVisibilityMask;
            
            ++offsets[0];
        }
        
        if (mask & (256 << i))
        {
            occlusionTriangleIDs[offsets[1]] = triangleID;
            
            ++offsets[1];
        }
    }
}

#define CALL_CONDENSE_TRIANGLES_COMMON(i)                                           \
condenseTrianglesCommon<doingColorUpdate>(renderTriangleIDs, occlusionTriangleIDs,  \
                                          triangleInclusions8, offsets8,            \
                                          baseTriangleID, offsets, mask, i);        \



kernel void condenseTriangles(CONDENSE_TRIANGLES_PARAMS)
{
    constexpr bool doingColorUpdate = false;
    
    PREPARE_CONDENSE_TRIANGLES;
    CONDENSE_GEOMETRY_REPEAT(CALL_CONDENSE_TRIANGLES_COMMON);
}

kernel void condenseTrianglesForColorUpdate(CONDENSE_TRIANGLES_PARAMS)
{
    constexpr bool doingColorUpdate = true;
    
    PREPARE_CONDENSE_TRIANGLES;
    CONDENSE_GEOMETRY_REPEAT(CALL_CONDENSE_TRIANGLES_COMMON);
}

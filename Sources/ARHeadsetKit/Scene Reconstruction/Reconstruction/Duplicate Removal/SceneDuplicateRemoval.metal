//
//  SceneDuplicateRemoval.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "../../../Other/Metal Utilities/MemoryUtilities.h"
using namespace metal;

constant float MATCHING_TOLERANCE = 2.4 / 256.0;
constant float DUPLICATE_REMOVAL_TOLERANCE = 1 / 256.0;
constant float DUPLICATE_REMOVAL_TOLERANCE_SQUARED = DUPLICATE_REMOVAL_TOLERANCE * DUPLICATE_REMOVAL_TOLERANCE;

kernel void findDuplicateVertices(device   bool     *vertexInclusionMarks             [[ buffer(0) ]],
                                  device   uint     *alternativeIDs                   [[ buffer(1) ]],
                                  
                                  constant float2x3 *smallSectorBounds                [[ buffer(2) ]],
                                  constant ushort   *microSectorToSmallSectorMappings [[ buffer(3) ]],
                                  constant ushort   *microSectorIDsInSmallSectors     [[ buffer(4) ]],
                                  device   ushort3  *dualIDBuffer                     [[ buffer(5) ]],
                                  device   float3   *worldSpacePositions              [[ buffer(6) ]],
                                  
                                  constant uint     *microSectorOffsets64             [[ buffer(7) ]],
                                  device   ushort   *nanoSectorOffsets                [[ buffer(8) ]],
                                  device   uchar    *nanoSectorCounts                 [[ buffer(9) ]],
                                  device   uint     *nanoSectorIDs                    [[ buffer(10) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    uint2 dualIDs = DualID::unpack(dualIDBuffer[id]);
    ushort idInMicroSector = dualIDs.y & 511;
    
    ushort3 nanoSectorIDVector;
    nanoSectorIDVector.xy = ushort2(idInMicroSector) >> ushort2(6, 3);
    nanoSectorIDVector.xy &= 7;
    nanoSectorIDVector.z = idInMicroSector & 7;
    
    uint   microSectorID = dualIDs.y >> 9;
    ushort idInSmallSector = microSectorIDsInSmallSectors[microSectorID];
    
    ushort3 microSectorIDVector;
    microSectorIDVector.xy = ushort2(idInSmallSector) >> ushort2(6, 3);
    microSectorIDVector.xy &= 7;
    microSectorIDVector.z = idInSmallSector & 7;

    ushort smallSectorID = microSectorToSmallSectorMappings[microSectorID];
    float3 bounds = smallSectorBounds[smallSectorID][0];
    bounds = fma(float3(nanoSectorIDVector), 1 / 32.0, fma(float3(microSectorIDVector), 0.25, bounds));
    
    float3 position = worldSpacePositions[dualIDs.x];
    float3 delta = position - bounds;
    
    if (any(delta < MATCHING_TOLERANCE) ||
        any(delta >= 1 / 32.0 + MATCHING_TOLERANCE))
    {
        return;
    }
    
    nanoSectorIDs[dualIDs.x] = dualIDs.y;
    
    ushort numNeighbors = nanoSectorCounts[dualIDs.y];
    if (numNeighbors == 1) { return; }
    
    uint i = microSectorOffsets64[microSectorID >> 6] + nanoSectorOffsets[dualIDs.y];
    uint i_end = i + numNeighbors;
    uint i_end_minus_1 = i_end - 1;

    uint lowestSimilarID = dualIDs.x;
    bool foundSameID = false;
    
    for (; i < i_end; ++i)
    {
        if (i == i_end_minus_1 && !foundSameID) { break; }

        uint neighborVertexID = DualID::getX(dualIDBuffer[i]);
        if (neighborVertexID == dualIDs.x)
        {
            foundSameID = true;
            continue;
        }
        
        if (distance_squared(worldSpacePositions[neighborVertexID], position) < DUPLICATE_REMOVAL_TOLERANCE_SQUARED)
        {
            lowestSimilarID = min(lowestSimilarID, neighborVertexID);
        }
    }

    if (lowestSimilarID != dualIDs.x)
    {
        vertexInclusionMarks[dualIDs.x] = false;
        alternativeIDs[dualIDs.x] = lowestSimilarID;
    }
}

kernel void markOriginalVertexOffsets4(device   uint4  *alternativeIDs           [[ buffer(1) ]],
                                       device   ushort *offsets4                 [[ buffer(2) ]],
                                       constant uint   *offsets4096              [[ buffer(3) ]],
                                       
                                       device   uint   *vertexNanoSectorMappings [[ buffer(4) ]],
                                       device   uint4  *nanoSectorIDs            [[ buffer(5) ]],
                                       device   bool4  *vertexInclusionMarks     [[ buffer(7) ]],
                                       
                                       uint id [[ thread_position_in_grid ]])
{
    bool4 marks = vertexInclusionMarks[id];
    uint4 offsets = { offsets4096[id >> 10] + offsets4[id] };
    
    uint4 selectedNanoSectorIDs = nanoSectorIDs[id];
    
    if (all(marks))
    {
        offsets[1] = offsets[0] + 1;
        offsets[2] = offsets[0] + 2;
        offsets[3] = offsets[0] + 3;
        
        alternativeIDs[id] = offsets;
        
        for (uchar i = 0; i < 4; ++i)
        {
            vertexNanoSectorMappings[offsets[i]] = selectedNanoSectorIDs[i];
        }
    }
    else
    {
        auto targetAlternativeIDPointer = reinterpret_cast<device uint*>(alternativeIDs + id);
        
        for (uchar i = 0; i < 4; ++i)
        {
            if (marks[i])
            {
                targetAlternativeIDPointer[i] = offsets[0];
                vertexNanoSectorMappings[offsets[0]] = selectedNanoSectorIDs[i];
                ++offsets[0];
            }
        }
    }
}



inline ushort increment_map_count(device atomic_uint *atomicCounts, uint vertexID)
{
    uint countID = vertexID >> 2;
    uint power = (vertexID & 3) << 3;
    
    uint offset = atomic_fetch_add_explicit(atomicCounts + countID, 1 << power, memory_order_relaxed);
    return 255 & (offset >> power);
}

kernel void removeDuplicateGeometry(device   bool        *triangleInclusionMarks [[ buffer(0) ]],
                                    constant uint        *alternativeIDs         [[ buffer(1) ]],
                                    
                                    constant uint        &numNanoSectors         [[ buffer(2) ]],
                                    constant uint        &numTriangles           [[ buffer(3) ]],
                                    constant uint        &numVertices            [[ buffer(4) ]],
                                    
                                    device   ushort3     *dualIDBuffer           [[ buffer(5) ]],
                                    device   uint3       *reducedIndices         [[ buffer(6) ]],
                                    constant bool        *vertexInclusionMarks   [[ buffer(7) ]],
                                    
                                    device   uint        *mappingsFinal          [[ buffer(8) ]],
                                    constant uint        *microSectorOffsets64   [[ buffer(9) ]],
                                    device   ushort      *nanoSectorOffsets      [[ buffer(10) ]],
                                    device   uchar       *nanoSectorCounts       [[ buffer(11) ]],
                                    
                                    device   atomic_uint *vertexMapCounts        [[ buffer(12) ]],
                                    device   uchar       *vertexMaps             [[ buffer(13) ]],
                                    
                                    uint id [[ thread_position_in_grid ]])
{
    if (id < numVertices)
    {
        if (!vertexInclusionMarks[id])
        {
            uint destinationID = alternativeIDs[id];
            
            while (!vertexInclusionMarks[destinationID])
            {
                destinationID = alternativeIDs[destinationID];
            }
            
            ushort mapCount = increment_map_count(vertexMapCounts, destinationID);
            
            if (mapCount < 10)
            {
                PackedID10::set(vertexMaps, mapCount, id, destinationID << 5);
            }
        }
    }
    
    if (id < numTriangles)
    {
        uint3 indices = reducedIndices[id];
        
        for (uchar i = 0; i < 3; ++i)
        {
            while (!vertexInclusionMarks[indices[i]])
            {
                indices[i] = alternativeIDs[indices[i]];
            }
            
            indices[i] = alternativeIDs[indices[i]];
        }
        
        if (any(indices == indices.yzx)) { triangleInclusionMarks[id] = false; }
        
        reducedIndices[id] = indices;
    }
    
    if (id >= numNanoSectors)
    {
        return;
    }
    
    uint nanoSectorID = mappingsFinal[id];
    ushort originalCount = nanoSectorCounts[nanoSectorID];
    
    uint i     = microSectorOffsets64[nanoSectorID >> 15] + nanoSectorOffsets[nanoSectorID];
    uint i_end = i + originalCount;
    
    uint j = i;
    ushort finalCount = 0;

    for (; i < i_end; ++i)
    {
        uint vertexID = DualID::getX(dualIDBuffer[i]);
        
        if (vertexInclusionMarks[vertexID])
        {
            DualID::setX(dualIDBuffer + j, alternativeIDs[vertexID]);
            ++j;
            ++finalCount;
        }
    }
    
    if (finalCount != originalCount)
    {
        nanoSectorCounts[nanoSectorID] = finalCount;
    }
}

kernel void combineDuplicateVertices(constant uint   *alternativeIDs       [[ buffer(1) ]],
                                     device   float3 *worldSpacePositions  [[ buffer(2) ]],
                                     device   half3  *worldSpaceNormals    [[ buffer(3) ]],
                                     
                                     device   float3 *outputVertices       [[ buffer(4) ]],
                                     device   half3  *outputNormals        [[ buffer(5) ]],
                                     constant bool   *vertexInclusionMarks [[ buffer(7) ]],
                                     
                                     device   uchar  *vertexMapCounts      [[ buffer(12) ]],
                                     device   uchar  *vertexMaps           [[ buffer(13) ]],
                                     
                                     uint id [[ thread_position_in_grid ]])
{
    if (!vertexInclusionMarks[id]) { return; }
    
    float3 position = worldSpacePositions[id];
    ushort numDuplicates = vertexMapCounts[id];
    uint destinationID = alternativeIDs[id];
    
    half3 normal = worldSpaceNormals[id];
    
    if (numDuplicates > 0)
    {
        vertexMapCounts[id] = 0;
        
        float3 normalSum = float3(normal);
        auto vertexMapPointer = vertexMaps + (id << 5);
        numDuplicates = min(ushort(10), numDuplicates);
        
        for (ushort i = 0; i < numDuplicates; vertexMapPointer += 3)
        {
            uint duplicateID = PackedID10::get(vertexMapPointer, 0);
            
            position  +=        worldSpacePositions[duplicateID];
            normalSum += float3(worldSpaceNormals  [duplicateID]);
            
            ++i;
        }
        
        constexpr float possibleMultipliers[11] = {
            NAN,     1 /  2.0, 1 /  3.0, 1 / 4.0,
            1 / 5.0, 1 /  6.0, 1 /  7.0, 1 / 8.0,
            1 / 9.0, 1 / 10.0, 1 / 11.0
        };
        
        float normalizationMultiplier = possibleMultipliers[numDuplicates];
        
        position *= normalizationMultiplier;
        normal = half3(precise::normalize(normalSum));
    }
    
    outputVertices[destinationID] = position;
    outputNormals [destinationID] = normal;
}



inline void registerVertexMapping(device atomic_uint *vertexMapCounts, uint index,
                                  device uchar       *vertexMaps,      uint triangleID)
{
    ushort mapCount = increment_map_count(vertexMapCounts, index);

    if (mapCount < 10)
    {
        PackedID10::set(vertexMaps, mapCount, triangleID, index << 5);
    }
}

inline void registerVertexMappings(device atomic_uint *vertexMapCounts, uint3 indices,
                                   device uchar       *vertexMaps,      uint  triangleID)
{
    registerVertexMapping(vertexMapCounts, indices[0], vertexMaps, triangleID);
    registerVertexMapping(vertexMapCounts, indices[1], vertexMaps, triangleID);
    registerVertexMapping(vertexMapCounts, indices[2], vertexMaps, triangleID);
}

kernel void condenseIncludedTriangles(device   bool4       *triangleInclusionMarks [[ buffer(0) ]],
                                      constant uint        *offsets4096            [[ buffer(1) ]],
                                      device   ushort      *offsets4               [[ buffer(2) ]],

                                      device   uint3       *inputIndices           [[ buffer(3) ]],
                                      device   uint3       *outputIndices          [[ buffer(4) ]],
                                      device   atomic_uint *vertexMapCounts        [[ buffer(5) ]],
                                      device   uchar       *vertexMaps             [[ buffer(6) ]],

                                      uint id [[ thread_position_in_grid ]])
{
    bool4 marks = triangleInclusionMarks[id];
    
    uint oldTriangleID = id << 2;
    uint newTriangleID = offsets4096[id >> 10] + offsets4[id];
    
#define CONDENSE_INCLUDED_TRIANGLES_BLOCK(i)                    \
{                                                               \
    uint3 selectedIndices = inputIndices[oldTriangleID + i];    \
    outputIndices[newTriangleID] = selectedIndices;             \
                                                                \
    registerVertexMappings(vertexMapCounts, selectedIndices,    \
                           vertexMaps,      newTriangleID);     \
                                                                \
    if (i < 3)                                                  \
    {                                                           \
        ++newTriangleID;                                        \
    }                                                           \
}                                                               \
    
    if (marks[0]) { CONDENSE_INCLUDED_TRIANGLES_BLOCK(0); }
    if (marks[1]) { CONDENSE_INCLUDED_TRIANGLES_BLOCK(1); }
    if (marks[2]) { CONDENSE_INCLUDED_TRIANGLES_BLOCK(2); }
    if (marks[3]) { CONDENSE_INCLUDED_TRIANGLES_BLOCK(3); }
}
#endif

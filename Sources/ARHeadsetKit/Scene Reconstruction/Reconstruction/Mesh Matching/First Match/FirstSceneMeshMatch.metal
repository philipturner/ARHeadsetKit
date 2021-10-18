//
//  FirstSceneMeshMatch.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#include <metal_stdlib>
#include "../../../../Other/Metal Utilities/MemoryUtilities.h"
using namespace metal;

constant float MATCHING_TOLERANCE = 5 / 256.0;
constant float MATCHING_TOLERANCE_SQUARED = MATCHING_TOLERANCE * MATCHING_TOLERANCE;

constant uchar MATCH_VERTICES_CACHE_SIZE = 5;
constant uchar WRITE_MATCHED_VERTICES_CACHE_SIZE = 4;

kernel void mapMeshSmallSectors(constant ushort *oldSmallSectorMappings   [[ buffer(0) ]],
                                constant uint   *oldSmallSectorHashes     [[ buffer(1) ]],
                                constant ushort &numOldSmallSectorsMinus1 [[ buffer(2) ]],
                                
                                device   ushort *newSmallSectorMappings   [[ buffer(3) ]],
                                constant uint   *newSmallSectorHashes     [[ buffer(4) ]],
                                
                                ushort id [[ thread_position_in_grid ]])
{
    uint smallSectorHash = newSmallSectorHashes[id];
    ushort hashLocation = BinarySearch::binarySearch(smallSectorHash, oldSmallSectorHashes,
                                                     numOldSmallSectorsMinus1);
    
    if (oldSmallSectorHashes[hashLocation] == smallSectorHash)
    {
        newSmallSectorMappings[id] = oldSmallSectorMappings[hashLocation];
    }
    else
    {
        newSmallSectorMappings[id] = __UINT16_MAX__;
    }
}



#define MATCH_VERTICES_GET_ID(a)                                                \
cachedCandidateIDs[a] = DualID::getX(oldDualIDs[i_start_plus_cache_offset]);    \
cachedCandidatePositions[a] = oldReducedVertices[cachedCandidateIDs[a]];        \
++i_start_plus_cache_offset;                                                    \

kernel void matchMeshVertices(device   float3  *newReducedVertices                  [[ buffer(0) ]],
                              device   uint    *newVertexNanoSectorMappings         [[ buffer(2) ]],
                              
                              constant ushort  *newSmallSectorMappings              [[ buffer(3) ]],
                              constant ushort  *newMicroSectorToSmallSectorMappings [[ buffer(4) ]],
                              constant ushort  *newMicroSectorIDsInSmallSectors     [[ buffer(5) ]],
                              
                              device   float3  *oldReducedVertices                  [[ buffer(6) ]],
                              device   ushort  *oldMicroSectorLocations             [[ buffer(7) ]],
                              device   ushort2 *oldMicroSectorCounts512th           [[ buffer(8) ]],
                              constant uint    *oldMicroSectorOffsets64             [[ buffer(9) ]],
                              
                              device   ushort  *oldNanoSectorOffsets                [[ buffer(10) ]],
                              device   uchar   *oldNanoSectorCounts                 [[ buffer(11) ]],
                              device   ushort3 *oldDualIDs                          [[ buffer(12) ]],
                              
                              device   ushort  *vertexMatchCounts                   [[ buffer(13) ]],
                              constant uint    &preCullVertexCount                  [[ buffer(14) ]],
                              device   uchar   *vertexMatchCounts16                 [[ buffer(15) ]],
                              device   uchar   *vertexMatchOffsets                  [[ buffer(16) ]],
                              
                              uint id [[ thread_position_in_grid ]])
{
    uint i_start_plus_cache_offset;
    uint i_end;
    
    uint j     = id << 4;
    uint j_end = min(j + 16, preCullVertexCount);
    
    uint   cachedCandidateIDs      [MATCH_VERTICES_CACHE_SIZE];
    float3 cachedCandidatePositions[MATCH_VERTICES_CACHE_SIZE];
    ushort numCachedVertices;
    
    ushort cachedNewMicroSectorID = __UINT16_MAX__;
    ushort cachedOldMicroSectorID;
    
    uint cachedNewNanoSectorID = __UINT32_MAX__;
    uint cachedOldNanoSectorID;
    
    bool shouldStopMicroSector;
    bool shouldStopNanoSector;
    
    ushort offset = 0;
    
    for (; j < j_end; j += 4)
    {
        ushort cachedCounts = 0;
        uchar4 cachedOffsets;
        
        ushort k_end = min(ushort(4), ushort(j_end - j));
        
        for (ushort k = 0; k < k_end; ++k)
        {
            cachedOffsets[k] = offset;
            uint vertexID = j + k;
            
            uint sampleNewNanoSectorID = newVertexNanoSectorMappings[vertexID];
            if (sampleNewNanoSectorID != cachedNewNanoSectorID)
            {
                cachedNewNanoSectorID = sampleNewNanoSectorID;
                
                ushort sampleNewMicroSectorID = sampleNewNanoSectorID >> 9;
                if (sampleNewMicroSectorID != cachedNewMicroSectorID)
                {
                    cachedNewMicroSectorID = sampleNewMicroSectorID;
                    
                    ushort newSmallSectorID = newMicroSectorToSmallSectorMappings[cachedNewMicroSectorID];
                    ushort oldSmallSectorID = newSmallSectorMappings[newSmallSectorID];
                    
                    shouldStopMicroSector = (oldSmallSectorID == __UINT16_MAX__);
                    if (shouldStopMicroSector)
                    {
                        shouldStopNanoSector = true;
                        continue;
                    }
                    
                    ushort idInSmallSector = newMicroSectorIDsInSmallSectors[cachedNewMicroSectorID];
                    uint oldExpandedMicroSectorID = (uint(oldSmallSectorID) << 9) + idInSmallSector;
                    
                    if (oldMicroSectorCounts512th[oldExpandedMicroSectorID].x == 0)
                    {
                        shouldStopNanoSector = true;
                        shouldStopMicroSector = true;
                        continue;
                    }
                    
                    cachedOldMicroSectorID = oldMicroSectorLocations[oldExpandedMicroSectorID];
                }
                else if (shouldStopMicroSector)
                {
                    shouldStopNanoSector = true;
                    continue;
                }
                
                ushort idInMicroSector = cachedNewNanoSectorID & 511;
                cachedOldNanoSectorID = (uint(cachedOldMicroSectorID) << 9) + idInMicroSector;
                
                ushort numNeighbors = oldNanoSectorCounts[cachedOldNanoSectorID];
                if (numNeighbors == 0)
                {
                    shouldStopNanoSector = true;
                    continue;
                }
                else
                {
                    shouldStopNanoSector = false;
                }
                
                ushort nanoSectorOffset   = oldNanoSectorOffsets[cachedOldNanoSectorID];
                i_start_plus_cache_offset = oldMicroSectorOffsets64[cachedOldMicroSectorID >> 6] + nanoSectorOffset;
                i_end                     = i_start_plus_cache_offset + numNeighbors;
                
                MATCH_VERTICES_GET_ID(0);
                if (i_start_plus_cache_offset < i_end)
                {
                    MATCH_VERTICES_GET_ID(1);
                    if (i_start_plus_cache_offset < i_end)
                    {
                        MATCH_VERTICES_GET_ID(2);
                        if (i_start_plus_cache_offset < i_end)
                        {
                            MATCH_VERTICES_GET_ID(3);
                            if (i_start_plus_cache_offset < i_end)
                            {
                                MATCH_VERTICES_GET_ID(MATCH_VERTICES_CACHE_SIZE - 1);
                                numCachedVertices = MATCH_VERTICES_CACHE_SIZE;
                            }
                            else { numCachedVertices = 4; }
                        }
                        else { numCachedVertices = 3; }
                    }
                    else { numCachedVertices = 2; }
                }
                else
                {
                    numCachedVertices = 1;
                }
            }
            else if (shouldStopNanoSector)
            {
                continue;
            }
            
            float3 position = newReducedVertices[vertexID];
            float closestDistanceSquared = __FLT_MAX__;
            uint  closestID;
            
            ushort k_times_4 = k << 2;
            
#define MATCH_VERTICES_BLOCK(candidatePosition, candidateID, shouldTestFurther) \
float candidateDistanceSquared = distance_squared(candidatePosition, position); \
                                                                                \
if (candidateDistanceSquared < MATCHING_TOLERANCE_SQUARED)                      \
{                                                                               \
    if (candidateDistanceSquared < closestDistanceSquared)                      \
    {                                                                           \
        closestDistanceSquared = candidateDistanceSquared;                      \
        closestID = candidateID;                                                \
    }                                                                           \
    else if (shouldTestFurther)                                                 \
    {                                                                           \
        if (candidateDistanceSquared == closestDistanceSquared)                 \
        {                                                                       \
            closestID = min(closestID, candidateID);                            \
        }                                                                       \
    }                                                                           \
                                                                                \
    cachedCounts += 1 << k_times_4;                                             \
}                                                                               \
            
            MATCH_VERTICES_BLOCK(cachedCandidatePositions[0], cachedCandidateIDs[0], false);
            
            for (uchar i = 1; i < MATCH_VERTICES_CACHE_SIZE; ++i)
            {
                if (numCachedVertices <= i) { break; }
                
                MATCH_VERTICES_BLOCK(cachedCandidatePositions[i], cachedCandidateIDs[i], true);
            }

            for (uint i = i_start_plus_cache_offset; i < i_end; ++i)
            {
                if ((15 & (cachedCounts >> k_times_4)) == 15)
                {
                    break;
                }
                
                uint candidateID = DualID::getX(oldDualIDs[i]);
                float3 candidatePosition = oldReducedVertices[candidateID];
                
                MATCH_VERTICES_BLOCK(candidatePosition, candidateID, true);
            }

            if (closestDistanceSquared < MATCHING_TOLERANCE_SQUARED)
            {
                offset += 15 & (cachedCounts >> k_times_4);
            }
        }
        
        *reinterpret_cast<device uchar4*>(vertexMatchOffsets + j) = cachedOffsets;
        vertexMatchCounts[j >> 2] = cachedCounts;
    }
    
    vertexMatchCounts16[id] = offset;
}

kernel void countMatchedVertices64(device uchar4 *counts16 [[ buffer(15) ]],
                                   device ushort *counts64 [[ buffer(1) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    ushort4 counts = ushort4(counts16[id]);
    counts.xy += counts.zw;
    counts64[id] = counts[0] + counts[1];
}

kernel void countMatchedVertices512(device vec<ushort, 8> *counts64  [[ buffer(1) ]],
                                    device ushort         *counts512 [[ buffer(0) ]],
                                    
                                    uint id [[ thread_position_in_grid ]])
{
    uint4 counts = as_type<uint4>(counts64[id]);
    counts.xy += counts.zw;
    counts[0] += counts[1];
    
    counts512[id] = as_type<ushort2>(counts[0])[0] + as_type<ushort2>(counts[0])[1];
}



kernel void markMatchedVertexOffsets512(device vec<ushort, 8> *counts64   [[ buffer(0) ]],
                                        device vec<ushort, 8> *offsets64  [[ buffer(1) ]],
                                        device ushort         *offsets512 [[ buffer(2) ]],
                                        
                                        uint id [[ thread_position_in_grid ]])
{
    auto counts = counts64[id];
    vec<ushort, 8> offsets = { offsets512[id] };
    
    for (uchar i = 0; i < 7; ++i)
    {
        offsets[i + 1] = offsets[i] + counts[i];
    }
    
    offsets64[id] = offsets;
}

kernel void writeMatchedMeshVertices(constant ushort4 *vertexMatchCounts                   [[ buffer(0) ]],
                                     constant uchar4  *vertexMatchOffsets                  [[ buffer(1) ]],
                                     constant ushort  *vertexMatchOffsets16                [[ buffer(2) ]],
                                     constant uint    *vertexMatchOffsets4096              [[ buffer(3) ]],
                                     constant uint    &preCullVertexCount                  [[ buffer(4) ]],
                                     
                                     device   float3  *newReducedVertices                  [[ buffer(5) ]],
                                     device   uint    *newToOldVertexMatches               [[ buffer(6) ]],
                                     device   uint    *newVertexNanoSectorMappings         [[ buffer(7) ]],
                                     
                                     constant ushort  *newSmallSectorMappings              [[ buffer(8) ]],
                                     constant ushort  *newMicroSectorToSmallSectorMappings [[ buffer(9) ]],
                                     constant ushort  *newMicroSectorIDsInSmallSectors     [[ buffer(10) ]],
                                     
                                     device   float3  *oldReducedVertices                  [[ buffer(11) ]],
                                     device   ushort  *oldMicroSectorLocations             [[ buffer(12) ]],
                                     device   ushort2 *oldMicroSectorCounts512th           [[ buffer(13) ]],
                                     constant uint    *oldMicroSectorOffsets64             [[ buffer(14) ]],
                                     
                                     device   ushort  *oldNanoSectorOffsets                [[ buffer(15) ]],
                                     device   uchar   *oldNanoSectorCounts                 [[ buffer(16) ]],
                                     device   ushort3 *oldDualIDs                          [[ buffer(17) ]],
                                     
                                     uint id [[ thread_position_in_grid ]])
{
    uint i_start_plus_cache_offset;
    uint i_end;
    
    uint j     = id << 4;
    uint j_end = min(j + 16, preCullVertexCount);
    
    uint   cachedCandidateIDs      [WRITE_MATCHED_VERTICES_CACHE_SIZE];
    float3 cachedCandidatePositions[WRITE_MATCHED_VERTICES_CACHE_SIZE];
    ushort numCachedVertices;
    
    ushort cachedNewMicroSectorID = __UINT16_MAX__;
    ushort cachedOldMicroSectorID;
    
    uint cachedNewNanoSectorID = __UINT32_MAX__;
    uint cachedOldNanoSectorID;
    
    uint groupOffset = vertexMatchOffsets4096[id >> 8] + vertexMatchOffsets16[id];
    ushort4 groupMatchCounts = vertexMatchCounts[id];
    ushort countIndex = 0;
    
    for (; j < j_end; j += 4)
    {
        ushort selectedMatchCounts = groupMatchCounts[countIndex];
        ++countIndex;
        
        if (selectedMatchCounts == 0) { continue; }
        
        uchar4 withinGroupOffsets = vertexMatchOffsets[j >> 2];
        ushort k_end = min(ushort(4), ushort(j_end - j));
        
        for (ushort k = 0; k < k_end; ++k)
        {
            ushort matchCount = selectedMatchCounts & 15;
            selectedMatchCounts >>= 4;
            
            if (matchCount == 0) { continue; }
            uint vertexID = j + k;
            
            uint sampleNewNanoSectorID = newVertexNanoSectorMappings[vertexID];
            if (sampleNewNanoSectorID != cachedNewNanoSectorID)
            {
                cachedNewNanoSectorID = sampleNewNanoSectorID;
                
                ushort sampleNewMicroSectorID = sampleNewNanoSectorID >> 9;
                if (sampleNewMicroSectorID != cachedNewMicroSectorID)
                {
                    cachedNewMicroSectorID = sampleNewMicroSectorID;
                    
                    ushort newSmallSectorID = newMicroSectorToSmallSectorMappings[cachedNewMicroSectorID];
                    ushort oldSmallSectorID = newSmallSectorMappings[newSmallSectorID];
                    
                    ushort idInSmallSector = newMicroSectorIDsInSmallSectors[cachedNewMicroSectorID];
                    uint oldExpandedMicroSectorID = (uint(oldSmallSectorID) << 9) + idInSmallSector;
                    
                    cachedOldMicroSectorID = oldMicroSectorLocations[oldExpandedMicroSectorID];
                }
                
                ushort idInMicroSector = cachedNewNanoSectorID & 511;
                cachedOldNanoSectorID = (uint(cachedOldMicroSectorID) << 9) + idInMicroSector;
                
                ushort nanoSectorOffset = oldNanoSectorOffsets[cachedOldNanoSectorID];
                i_start_plus_cache_offset = oldMicroSectorOffsets64[cachedOldMicroSectorID >> 6] + nanoSectorOffset;
                
                ushort numNeighbors = oldNanoSectorCounts[cachedOldNanoSectorID];
                i_end = i_start_plus_cache_offset + numNeighbors;
                
                MATCH_VERTICES_GET_ID(0);
                if (i_start_plus_cache_offset < i_end)
                {
                    MATCH_VERTICES_GET_ID(1);
                    if (i_start_plus_cache_offset < i_end)
                    {
                        MATCH_VERTICES_GET_ID(2);
                        if (i_start_plus_cache_offset < i_end)
                        {
                            MATCH_VERTICES_GET_ID(WRITE_MATCHED_VERTICES_CACHE_SIZE - 1);
                            numCachedVertices = WRITE_MATCHED_VERTICES_CACHE_SIZE;
                        }
                        else { numCachedVertices = 3; }
                    }
                    else { numCachedVertices = 2; }
                }
                else
                {
                    numCachedVertices = 1;
                }
            }
            
            float3 position = newReducedVertices[vertexID];
            uint offset = groupOffset + withinGroupOffsets[k];
            
#define WRITE_MATCHED_VERTICES_BLOCK(candidatePosition, candidateID)            \
if (distance_squared(candidatePosition, position) < MATCHING_TOLERANCE_SQUARED) \
{                                                                               \
    newToOldVertexMatches[offset] = candidateID;                                \
    ++offset;                                                                   \
}                                                                               \
            
            WRITE_MATCHED_VERTICES_BLOCK(cachedCandidatePositions[0], cachedCandidateIDs[0]);
            
            for (uchar i = 1; i < WRITE_MATCHED_VERTICES_CACHE_SIZE; ++i)
            {
                if (numCachedVertices <= i) { break; }
                
                WRITE_MATCHED_VERTICES_BLOCK(cachedCandidatePositions[i], cachedCandidateIDs[i]);
            }
            
            for (uint i = i_start_plus_cache_offset; i < i_end; ++i)
            {
                uint candidateID = DualID::getX(oldDualIDs[i]);
                float3 candidatePosition = oldReducedVertices[candidateID];
                
                WRITE_MATCHED_VERTICES_BLOCK(candidatePosition, candidateID);
            }
        }
    }
}



inline bool testIndexMatch(constant uint *newToOldVertexMatches, uint vertexMatchStart,
                           ushort numVertexMatches, uint targetIndex)
{
    if (numVertexMatches == 0) { return false; }
    if (newToOldVertexMatches[vertexMatchStart] == targetIndex) { return true; }
    
    uint vertexMatchEnd  = vertexMatchStart + numVertexMatches;
    uint roundedMatchEnd = ~1 & vertexMatchEnd;
    if (newToOldVertexMatches[roundedMatchEnd] == targetIndex) { return true; }
    
    uint roundedMatchStart = ~1 & (vertexMatchStart + 1);
    
    for (uint i = roundedMatchStart; i < roundedMatchEnd; i += 2)
    {
        auto selectedMatches = *reinterpret_cast<constant uint2*>(newToOldVertexMatches + i);
        
        if (selectedMatches[0] == targetIndex ||
            selectedMatches[1] == targetIndex)
        {
            return true;
        }
    }
    
    return false;
}

kernel void matchMeshTriangles(constant uchar  *vertexMatchCountBuffer  [[ buffer(0) ]],
                               constant uchar  *vertexMatchOffsetBuffer [[ buffer(1) ]],
                               constant ushort *vertexMatchOffsets16    [[ buffer(2) ]],
                               constant uint   *vertexMatchOffsets4096  [[ buffer(3) ]],
                               
                               device   uint3  *newReducedIndexBuffer   [[ buffer(4) ]],
                               constant float3 *newReducedVertexBuffer  [[ buffer(5) ]],
                               constant uint   *newToOldVertexMatches   [[ buffer(6) ]],
                               device   uint   *newToOldTriangleMatches [[ buffer(7) ]],
                               
                               constant uint3  *oldReducedIndexBuffer   [[ buffer(8) ]],
                               constant uchar  *oldVertexMapCounts      [[ buffer(9) ]],
                               device   uchar  *oldVertexMaps           [[ buffer(10) ]],
                               constant float3 *oldReducedVertexBuffer  [[ buffer(11) ]],
                               
                               device   uchar  *newToOldMatchWindings   [[ buffer(18) ]],
                               device   bool   *matchExistsMarks        [[ buffer(19) ]],
                               
                               uint id [[ thread_position_in_grid ]])
{
    uint3 selectedIndices = newReducedIndexBuffer[id];
    ushort3 vertexMatchCounts;
    
    for (uchar i = 0; i < 3; ++i)
    {
        vertexMatchCounts[i] = vertexMatchCountBuffer[selectedIndices[i] >> 1];
    }
    
    vertexMatchCounts = select(vertexMatchCounts & 15, vertexMatchCounts >> 4, bool3(ushort3(selectedIndices) & 1));
    
    if (all(vertexMatchCounts != 0))
    {
        uint3 vertexMatchOffsets;
        
        for (uchar i = 0; i < 3; ++i)
        {
            if (vertexMatchCounts[i] != 0)
            {
                vertexMatchOffsets[i]  = vertexMatchOffsets4096 [selectedIndices[i] >> 12];
                vertexMatchOffsets[i] += vertexMatchOffsets16   [selectedIndices[i] >> 4];
                vertexMatchOffsets[i] += vertexMatchOffsetBuffer[selectedIndices[i]];
            }
        }
        
        float  minScore = __FLT_MAX__;
        uint   closestTriangleIndex = __UINT32_MAX__;
        ushort matchWinding;
        
        auto vertexMatchPointer = newToOldVertexMatches + vertexMatchOffsets.x;
        
        for (ushort i = 0; i < vertexMatchCounts[0]; ++i)
        {
            uint candidateVertexID = vertexMatchPointer[i];

            ushort candidateTriangleCount = oldVertexMapCounts[candidateVertexID];
            if (candidateTriangleCount == 0) { continue; }
            
            candidateTriangleCount = min(ushort(10), candidateTriangleCount);
            auto vertexMapPointer = oldVertexMaps + (candidateVertexID << 5);
            
            for (ushort j = 0; j < candidateTriangleCount; vertexMapPointer += 3)
            {
                uint candidateTriangleID = PackedID10::get(vertexMapPointer, 0);
                uint3 candidateIndices = oldReducedIndexBuffer[candidateTriangleID];
                
                ushort candidateMatchWinding;

                if (candidateVertexID == candidateIndices.y)
                {
                    candidateIndices = candidateIndices.yzx;
                    candidateMatchWinding = 1;
                }
                else if (candidateVertexID == candidateIndices.z)
                {
                    candidateIndices = candidateIndices.zxy;
                    candidateMatchWinding = 2;
                }
                else
                {
                    candidateMatchWinding = 0;
                }
                
                if (!testIndexMatch(newToOldVertexMatches, vertexMatchOffsets[1],
                                    vertexMatchCounts[1], candidateIndices[1]))
                {
                    ++j;
                    continue;
                }

                if (!testIndexMatch(newToOldVertexMatches, vertexMatchOffsets[2],
                                    vertexMatchCounts[2], candidateIndices[2]))
                {
                    ++j;
                    continue;
                }
                
                float3 distancesSquared;
                
                for (uchar i = 0; i < 3; ++i)
                {
                    distancesSquared[i] = distance_squared(oldReducedVertexBuffer[candidateIndices[i]],
                                                           newReducedVertexBuffer[ selectedIndices[i]]);
                }
                
                if (any(distancesSquared >= MATCHING_TOLERANCE_SQUARED))
                {
                    ++j;
                    continue;
                }
                
                float score = distancesSquared[0] + distancesSquared[1] + distancesSquared[2];
                
                if (score < minScore)
                {
                    closestTriangleIndex = candidateTriangleID;
                    minScore = score;
                    matchWinding = candidateMatchWinding;
                }
                
                ++j;
            }
        }
        
        if (closestTriangleIndex != __UINT32_MAX__)
        {
            if (minScore == 0)
            {
                matchWinding += 4;
                matchExistsMarks[closestTriangleIndex] = true;
            }
            
            newToOldTriangleMatches[id] = closestTriangleIndex;
            newToOldMatchWindings  [id] = matchWinding;
            
            return;
        }
    }
    
    auto targetPointer = reinterpret_cast<device uchar4*>(newToOldTriangleMatches);
    CorrectWrite::setW(targetPointer, id, 255);
}

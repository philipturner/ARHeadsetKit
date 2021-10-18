//
//  ThirdSceneMeshMatch.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/22/21.
//

#include <metal_stdlib>
#include "ThirdSceneMeshMatchTypes.metal"
#include "../../../../Other/Metal Utilities/MemoryUtilities.h"
using namespace metal;

inline void mark_micro_sector(device atomic_uint *atomicMarks, uint sectorID)
{
    uint markID = sectorID >> 2;
    uint power = (sectorID & 3) << 3;
    
    atomic_fetch_or_explicit(atomicMarks + markID, 1 << power, memory_order_relaxed);
}

inline void mark_sub_micro_sector(device atomic_uint *atomicMarks, uint sectorID)
{
    uint markID = sectorID >> 5;
    uint power = sectorID & 31;
    
    atomic_fetch_or_explicit(atomicMarks + markID, 1 << power, memory_order_relaxed);
}

kernel void prepareThirdMeshMatch(device   uint3       *newReducedIndexBuffer            [[ buffer(1) ]],
                                  device   float3      *newReducedVertexBuffer           [[ buffer(2) ]],
                                  device   uint        *newToOldTriangleMatches          [[ buffer(3) ]],
                                  
                                  constant ushort      &numNewSmallSectorsMinus1         [[ buffer(7) ]],
                                  constant ushort      *newSmallSectorMappings           [[ buffer(8) ]],
                                  constant uint        *newSmallSectorSortedHashes       [[ buffer(9) ]],
                                  constant ushort      *newSmallSectorSortedHashMappings [[ buffer(10) ]],
                                  
                                  device   ushort      *oldMicroSectorLocations          [[ buffer(13) ]],
                                  device   ushort2     *oldMicroSectorCounts512th        [[ buffer(14) ]],
                                  
                                  device   atomic_uint *oldSmallSectorMarks              [[ buffer(15) ]],
                                  device   atomic_uint *oldMicroSectorMarks              [[ buffer(16) ]],
                                  device   atomic_uint *oldSubMicroSectorMarks           [[ buffer(17) ]],
                                  device   atomic_uint *oldSuperNanoSectorMarks          [[ buffer(18) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    uint byteID = (id << 2) + 3;
    
    if (reinterpret_cast<device uchar*>(newToOldTriangleMatches)[byteID] != 253)
    {
        return;
    }
    
    Range<true> range(newReducedVertexBuffer, newReducedIndexBuffer[id]);
    
    uint smallSectorHash = (257 << 21) | (257 << 10) | 257;
    bool shouldStopSmallSector;
    uint oldExpandedMicroSectorBase;
    
    bool foundAMicroSector = false;
    bool shouldStopMicroSector;
    uint oldMicroSectorLocation;
    
    ushort microSectorID_inSmallSector;
    
    while (true)
    {
        uint newSmallSectorHash = range.getSmallSectorHash();
        
        bool shouldSearchForMicroSector;
        
        if (newSmallSectorHash == smallSectorHash)
        {
            if (shouldStopSmallSector)
            {
                shouldSearchForMicroSector = false;
            }
            else
            {
                ushort newMicroSectorID_inSmallSector = range.getMicroSectorID();
                
                shouldSearchForMicroSector  = newMicroSectorID_inSmallSector != microSectorID_inSmallSector;
                microSectorID_inSmallSector = newMicroSectorID_inSmallSector;
            }
        }
        else
        {
            microSectorID_inSmallSector = range.getMicroSectorID();
            
            smallSectorHash = newSmallSectorHash;
            ushort hashLocation = BinarySearch::binarySearch(smallSectorHash, newSmallSectorSortedHashes,
                                                             numNewSmallSectorsMinus1);
            
            if (newSmallSectorSortedHashes[hashLocation] == smallSectorHash)
            {
                ushort newSmallSectorLocation = newSmallSectorSortedHashMappings[hashLocation];
                ushort oldSmallSectorLocation = newSmallSectorMappings[newSmallSectorLocation];
                
                shouldStopSmallSector = oldSmallSectorLocation == __UINT16_MAX__;
                
                if (!shouldStopSmallSector)
                {
                    uchar retrievedMark = *reinterpret_cast<device uchar*>(oldSmallSectorMarks + oldSmallSectorLocation);
                    
                    if (retrievedMark == 0)
                    {
                        atomic_fetch_or_explicit(oldSmallSectorMarks + oldSmallSectorLocation, 1, memory_order_relaxed);
                    }
                    
                    oldExpandedMicroSectorBase = uint(oldSmallSectorLocation) << 9;
                    shouldSearchForMicroSector = true;
                }
            }
            else
            {
                shouldStopSmallSector = true;
            }
        }
        
        if (!shouldStopSmallSector)
        {
            if (shouldSearchForMicroSector)
            {
                uint oldExpandedMicroSectorID = oldExpandedMicroSectorBase + microSectorID_inSmallSector;
                shouldStopMicroSector = oldMicroSectorCounts512th[oldExpandedMicroSectorID].x == 0;
                
                if (!shouldStopMicroSector)
                {
                    oldMicroSectorLocation = oldMicroSectorLocations[oldExpandedMicroSectorID];
                    uchar retrievedMark = reinterpret_cast<device uchar*>(oldMicroSectorMarks)[oldMicroSectorLocation];
                    
                    if (retrievedMark == 0)
                    {
                        mark_micro_sector(oldMicroSectorMarks, oldMicroSectorLocation);
                    }
                    
                    foundAMicroSector = true;
                }
            }
            
            if (!shouldStopMicroSector)
            {
                ushort granularityPowerOf2 = range.getGranularityPowerOf2();
                
                if (granularityPowerOf2 < 3)
                {
                    uint location;
                    device atomic_uint *buffer;
                    
                    if (granularityPowerOf2 == 1)
                    {
                        location = uint(oldMicroSectorLocation) << 6;
                        buffer = oldSuperNanoSectorMarks;
                    }
                    else
                    {
                        location = uint(oldMicroSectorLocation) << 3;
                        buffer = oldSubMicroSectorMarks;
                    }
                    
                    location += range.getSubMicroSectorID();
                    
                    ushort mask = 1 << (location & 7);
                    ushort retrievedMark = reinterpret_cast<device uchar*>(buffer)[location >> 3] & mask;
                    
                    if (retrievedMark == 0)
                    {
                        mark_sub_micro_sector(buffer, location);
                    }
                }
            }
        }
        
        if (!range.increment())
        {
            if (!foundAMicroSector)
            {
                newToOldTriangleMatches[id] = 252 << 24;
            }
            
            return;
        }
    }
}



kernel void markMicroSectorColors(device   uint4       *oldReducedColorBuffer     [[ buffer(4) ]],
                                  device   uint3       *oldReducedIndexBuffer     [[ buffer(5) ]],
                                  device   float3      *oldReducedVertexBuffer    [[ buffer(6) ]],
                                  
                                  constant bool        &using8bitSmallSectorIDs   [[ buffer(11) ]],
                                  device   uchar       *smallSectorIDs            [[ buffer(12) ]],
                                  
                                  device   ushort      *oldMicroSectorLocations   [[ buffer(13) ]],
                                  device   ushort2     *oldMicroSectorCounts512th [[ buffer(14) ]],
                                  
                                  constant uchar4      *oldSmallSectorMarks       [[ buffer(15) ]],
                                  device   uchar       *oldMicroSectorMarks       [[ buffer(16) ]],
                                  device   uchar       *oldSubMicroSectorMarks    [[ buffer(17) ]],
                                  device   uchar       *oldSuperNanoSectorMarks   [[ buffer(18) ]],
                                  
                                  device   atomic_uint *microSectorColors         [[ buffer(19) ]],
                                  device   atomic_uint *subMicroSectorColors      [[ buffer(20) ]],
                                  device   atomic_uint *superNanoSectorColors     [[ buffer(21) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    ushort oldSmallSectorLocation = using8bitSmallSectorIDs ? smallSectorIDs [id]
                           : reinterpret_cast<device ushort*>(smallSectorIDs)[id];
    
    uchar retrievedMark = *reinterpret_cast<constant uchar*>(oldSmallSectorMarks + oldSmallSectorLocation);
    
    if (retrievedMark == 0)
    {
        return;
    }
    
    uint retrievedColor = *reinterpret_cast<device uint*>(oldReducedColorBuffer + id);
    
    if ((retrievedColor & 0x80000000) != 0)
    {
        return;
    }
    
    
    
    Range<false> range(oldReducedVertexBuffer, oldReducedIndexBuffer[id]);
    
    half2 chroma = half2(as_type<uchar4>(retrievedColor).gr) * (1.0 / 255);
    half  luma   = half (as_type<uchar4>(retrievedColor).b ) * (1.0 / 255);
    
    bool shouldStopMicroSector;
    uint oldExpandedMicroSectorBase = uint(oldSmallSectorLocation) << 9;;
    uint oldMicroSectorLocation;
    
    ushort microSectorID_inSmallSector = __UINT16_MAX__;
    
    while (true)
    {
        ushort oldMicroSectorID_inSmallSector = range.getMicroSectorID();
        
        if (oldMicroSectorID_inSmallSector != microSectorID_inSmallSector)
        {
            microSectorID_inSmallSector = oldMicroSectorID_inSmallSector;
            uint oldExpandedMicroSectorID = oldExpandedMicroSectorBase + microSectorID_inSmallSector;
            
            if (oldMicroSectorCounts512th[oldExpandedMicroSectorID].x != 0)
            {
                oldMicroSectorLocation = oldMicroSectorLocations[oldExpandedMicroSectorID];
                shouldStopMicroSector = oldMicroSectorMarks[oldMicroSectorLocation] == 0;
            }
            else
            {
                shouldStopMicroSector = true;
            }
        }
        
        if (!shouldStopMicroSector)
        {
            ushort granularityPowerOf2 = range.getGranularityPowerOf2();

            uint location;
            ushort mask;

            device uchar       *markBuffer;
            device atomic_uint *colorBuffer;

            if (granularityPowerOf2 == 3)
            {
                location = uint(oldMicroSectorLocation);
                mask = 255;

                markBuffer  = oldMicroSectorMarks;
                colorBuffer = microSectorColors;
            }
            else
            {
                if (granularityPowerOf2 == 1)
                {
                    location = uint(oldMicroSectorLocation) << 6;

                    markBuffer  = oldSuperNanoSectorMarks;
                    colorBuffer = superNanoSectorColors;
                }
                else
                {
                    location = uint(oldMicroSectorLocation) << 3;

                    markBuffer  = oldSubMicroSectorMarks;
                    colorBuffer = subMicroSectorColors;
                }

                location += range.getSubMicroSectorID();
                mask = 1 << (location & 7);
            }

            ushort retrievedMark = markBuffer[location] & mask;

            if (retrievedMark != 0)
            {
                range.contributeColor(chroma, luma, colorBuffer + (location << 1));
            }
        }
        
        if (!range.increment())
        {
            return;
        }
    }
}



kernel void executeThirdMeshMatch(device   uint4   *newReducedColorBuffer            [[ buffer(0) ]],
                                  device   uint3   *newReducedIndexBuffer            [[ buffer(1) ]],
                                  device   float3  *newReducedVertexBuffer           [[ buffer(2) ]],
                                  device   uint    *newToOldTriangleMatches          [[ buffer(3) ]],
                                  
                                  constant ushort  &numNewSmallSectorsMinus1         [[ buffer(7) ]],
                                  constant ushort  *newSmallSectorMappings           [[ buffer(8) ]],
                                  constant uint    *newSmallSectorSortedHashes       [[ buffer(9) ]],
                                  constant ushort  *newSmallSectorSortedHashMappings [[ buffer(10) ]],
                                  
                                  device   ushort  *oldMicroSectorLocations          [[ buffer(13) ]],
                                  device   ushort2 *oldMicroSectorCounts512th        [[ buffer(14) ]],
                                  
                                  device   half4   *microSectorColors                [[ buffer(19) ]],
                                  device   half4   *subMicroSectorColors             [[ buffer(20) ]],
                                  device   half4   *superNanoSectorColors            [[ buffer(21) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    uint byteID = (id << 2) + 3;
    
    if (reinterpret_cast<device uchar*>(newToOldTriangleMatches)[byteID] != 253)
    {
        return;
    }
    
    Range<true> range(newReducedVertexBuffer, newReducedIndexBuffer[id]);
    
    half4 accumulatedColor = half4(0);
    
    uint smallSectorHash = (257 << 21) | (257 << 10) | 257;
    bool shouldStopSmallSector;
    uint oldExpandedMicroSectorBase;
    
    bool shouldStopMicroSector;
    uint oldMicroSectorLocation;
    
    ushort microSectorID_inSmallSector;
    
    while (true)
    {
        uint newSmallSectorHash = range.getSmallSectorHash();
        bool shouldSearchForMicroSector;
        
        if (newSmallSectorHash == smallSectorHash)
        {
            if (shouldStopSmallSector)
            {
                shouldSearchForMicroSector = false;
            }
            else
            {
                ushort newMicroSectorID_inSmallSector = range.getMicroSectorID();
                
                shouldSearchForMicroSector  = newMicroSectorID_inSmallSector != microSectorID_inSmallSector;
                microSectorID_inSmallSector = newMicroSectorID_inSmallSector;
            }
        }
        else
        {
            microSectorID_inSmallSector = range.getMicroSectorID();
            
            smallSectorHash = newSmallSectorHash;
            ushort hashLocation = BinarySearch::binarySearch(smallSectorHash, newSmallSectorSortedHashes,
                                                             numNewSmallSectorsMinus1);
            
            if (newSmallSectorSortedHashes[hashLocation] == smallSectorHash)
            {
                ushort newSmallSectorLocation = newSmallSectorSortedHashMappings[hashLocation];
                ushort oldSmallSectorLocation = newSmallSectorMappings[newSmallSectorLocation];
                
                shouldStopSmallSector = oldSmallSectorLocation == __UINT16_MAX__;
                oldExpandedMicroSectorBase = uint(oldSmallSectorLocation) << 9;
            }
            else
            {
                shouldStopSmallSector = true;
            }
            
            shouldSearchForMicroSector = !shouldStopSmallSector;
        }
        
        if (!shouldStopSmallSector)
        {
            if (shouldSearchForMicroSector)
            {
                uint oldExpandedMicroSectorID = oldExpandedMicroSectorBase + microSectorID_inSmallSector;
                shouldStopMicroSector = oldMicroSectorCounts512th[oldExpandedMicroSectorID].x == 0;
                
                if (!shouldStopMicroSector)
                {
                    oldMicroSectorLocation = oldMicroSectorLocations[oldExpandedMicroSectorID];
                }
            }
            
            if (!shouldStopMicroSector)
            {
                ushort granularityPowerOf2 = range.getGranularityPowerOf2();

                uint location;
                device half4 *colorBuffer;

                if (granularityPowerOf2 == 3)
                {
                    location = uint(oldMicroSectorLocation);
                    colorBuffer = microSectorColors;
                }
                else
                {
                    if (granularityPowerOf2 == 1)
                    {
                        location = uint(oldMicroSectorLocation) << 6;
                        colorBuffer = superNanoSectorColors;
                    }
                    else
                    {
                        location = uint(oldMicroSectorLocation) << 3;
                        colorBuffer = subMicroSectorColors;
                    }

                    location += range.getSubMicroSectorID();
                }

                half4 retrievedColor = colorBuffer[location];
                range.addColor(retrievedColor, accumulatedColor);
            }
        }
        
        if (!range.incrementWithColor(accumulatedColor.x))
        {
            if (accumulatedColor.x == 0)
            {
                newToOldTriangleMatches[id] = 252 << 24;
            }
            else
            {
                accumulatedColor.x = fast::divide(1, float(accumulatedColor.x));
                half3 YCbCr = accumulatedColor.yzw * accumulatedColor.x;
                YCbCr = min(1, YCbCr);
                
                uchar3 CrCbY = uchar3(rint(YCbCr.bgr * 255));
                uint output = as_type<uint>(uchar4(CrCbY, 0));
                
                newReducedColorBuffer[id] = uint4(output);
                newToOldTriangleMatches[id] = 254 << 24;
            }
            
            return;
        }
    }
}

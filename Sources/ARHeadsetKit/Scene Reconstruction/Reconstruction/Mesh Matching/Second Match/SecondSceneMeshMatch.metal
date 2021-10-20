//
//  SecondSceneMeshMatch.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "SecondSceneMeshMatchTypes.metal"
#include "../../../../Other/Metal Utilities/MemoryUtilities.h"
using namespace metal;



inline void mark_micro_sector(device atomic_uint *atomicMarks, uint sectorID)
{
    uint markID = sectorID >> 2;
    uint power = (sectorID & 3) << 3;
    
    atomic_fetch_or_explicit(atomicMarks + markID, 1 << power, memory_order_relaxed);
}

inline void mark_nano_sector(device atomic_uint *atomicMarks, uint sectorID)
{
    uint markID = sectorID >> 5;
    uint power = sectorID & 31;
    
    atomic_fetch_or_explicit(atomicMarks + markID, 1 << power, memory_order_relaxed);
}

kernel void prepareSecondMeshMatch(device   uint3       *newReducedIndexBuffer            [[ buffer(1) ]],
                                   device   float3      *newReducedVertexBuffer           [[ buffer(2) ]],
                                   device   uint        *newToOldTriangleMatches          [[ buffer(3) ]],
                                   
                                   device   bool        &shouldDoThirdMatch               [[ buffer(5) ]],
                                   constant ushort      &numNewSmallSectorsMinus1         [[ buffer(6) ]],
                                   constant ushort      *newSmallSectorMappings           [[ buffer(7) ]],
                                   constant uint        *newSmallSectorSortedHashes       [[ buffer(8) ]],
                                   constant ushort      *newSmallSectorSortedHashMappings [[ buffer(9) ]],
                                   
                                   device   ushort      *oldMicroSectorLocations          [[ buffer(12) ]],
                                   device   ushort2     *oldMicroSectorCounts512th        [[ buffer(13) ]],
                                   
                                   device   atomic_uint *oldSmallSectorMarks              [[ buffer(14) ]],
                                   device   atomic_uint *oldMicroSectorMarks              [[ buffer(15) ]],
                                   device   atomic_uint *oldNanoSectorMarks               [[ buffer(16) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    uint byteID = (id << 2) + 3;

    if (reinterpret_cast<device uchar*>(newToOldTriangleMatches)[byteID] < 255)
    {
        return;
    }
    
    Range<false> range(newReducedVertexBuffer, newReducedIndexBuffer[id]);
    
    uint smallSectorHash = range.getSmallSectorHash();
    ushort hashLocation = BinarySearch::binarySearch(smallSectorHash, newSmallSectorSortedHashes,
                                                     numNewSmallSectorsMinus1);
    uint oldExpandedMicroSectorBase;
    bool foundASmallSector;
    
    if (newSmallSectorSortedHashes[hashLocation] == smallSectorHash)
    {
        ushort newSmallSectorLocation = newSmallSectorSortedHashMappings[hashLocation];
        ushort oldSmallSectorLocation = newSmallSectorMappings[newSmallSectorLocation];
        
        foundASmallSector = oldSmallSectorLocation != __UINT16_MAX__;
        
        if (foundASmallSector)
        {
            uchar retrievedMark = *reinterpret_cast<device uchar*>(oldSmallSectorMarks + oldSmallSectorLocation);
            
            if (retrievedMark == 0)
            {
                atomic_fetch_or_explicit(oldSmallSectorMarks + oldSmallSectorLocation, 1, memory_order_relaxed);
            }
            
            oldExpandedMicroSectorBase = uint(oldSmallSectorLocation) << 9;
        }
    }
    else
    {
        foundASmallSector = false;
    }
    
    if (!foundASmallSector)
    {
        newToOldTriangleMatches[id] = 253 << 24;
        
        if (!shouldDoThirdMatch)
        {
            shouldDoThirdMatch = true;
        }
        
        return;
    }
    
    
    
    bool foundAMicroSector = false;
    bool shouldStopMicroSector;
    uint oldExpandedNanoSectorBase;
    
    ushort microSectorID_inSmallSector = __UINT16_MAX__;
    
    while (true)
    {
        ushort newMicroSectorID_inSmallSector = range.getMicroSectorID();
         
        if (newMicroSectorID_inSmallSector != microSectorID_inSmallSector)
        {
            microSectorID_inSmallSector = newMicroSectorID_inSmallSector;
            
            uint oldExpandedMicroSectorID = oldExpandedMicroSectorBase + microSectorID_inSmallSector;
            shouldStopMicroSector = oldMicroSectorCounts512th[oldExpandedMicroSectorID].x == 0;
            
            if (!shouldStopMicroSector)
            {
                ushort oldMicroSectorLocation = oldMicroSectorLocations[oldExpandedMicroSectorID];
                oldExpandedNanoSectorBase = uint(oldMicroSectorLocation) << 9;
                
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
            uint oldNanoSectorLocation = oldExpandedNanoSectorBase + range.getNanoSectorID();
            
            ushort mask = 1 << (oldNanoSectorLocation & 7);
            ushort retrievedMark = reinterpret_cast<device uchar*>(oldNanoSectorMarks)[oldNanoSectorLocation >> 3] & mask;
            
            if (retrievedMark == 0)
            {
                mark_nano_sector(oldNanoSectorMarks, oldNanoSectorLocation);
            }
        }
        
        if (!range.increment())
        {
            if (!foundAMicroSector)
            {
                newToOldTriangleMatches[id] = 253 << 24;
                
                if (!shouldDoThirdMatch)
                {
                    shouldDoThirdMatch = true;
                }
            }
            
            return;
        }
    }
}



kernel void countNanoSectors4thForMatch(device uchar  *counts4th        [[ buffer(0) ]],
                                        device uchar4 *offsets16th      [[ buffer(1) ]],
                                        
                                        device bool   *microSectorMarks [[ buffer(15) ]],
                                        device uint4  *nanoSectorMarks  [[ buffer(16) ]],
                                        
                                        uint id [[ thread_position_in_grid ]])
{
    if (!microSectorMarks[id >> 2])
    {
        return;
    }
    
    uint4 retrievedMarks = nanoSectorMarks[id];
    ushort4 counts;
    
    for (uchar i = 0; i < 4; ++i)
    {
        counts[i] = popcount(retrievedMarks[i]);
    }
    
    ushort3 partialSums;
    partialSums.xz = counts.xz + counts.yw;
    partialSums.yz = ushort2(partialSums.x) + ushort2(counts.z, partialSums.z);
    
    counts4th[id]   = partialSums.z;
    offsets16th[id] = uchar4(uchar2(0, counts.x), uchar2(partialSums.xy));
}

kernel void countNanoSectors1ForMatch(device uchar4 *counts4th        [[ buffer(0) ]],
                                      device ushort *countsIndividual [[ buffer(1) ]],
                                      device bool   *microSectorMarks [[ buffer(15) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    if (!microSectorMarks[id])
    {
        return;
    }
    
    uchar4 retrievedCounts = counts4th[id];
    ushort2 intermediateCounts = ushort2(retrievedCounts.xy) + ushort2(retrievedCounts.zw);
    
    countsIndividual[id] = intermediateCounts.x + intermediateCounts.y;
}

kernel void countNanoSectors4to16ForMatch(device ushort4 *counts_in  [[ buffer(1) ]],
                                          device ushort  *counts_out [[ buffer(2) ]],
                                          
                                          uint id [[ thread_position_in_grid ]])
{
    ushort4 retrievedCounts = counts_in[id];
    retrievedCounts.xy += retrievedCounts.zw;
    
    counts_out[id] = retrievedCounts.x + retrievedCounts.y;
}

kernel void scanNanoSectors64ForMatch(device ushort4 *counts16  [[ buffer(2) ]],
                                      device ushort  *counts64  [[ buffer(3) ]],
                                      device ushort4 *offsets16 [[ buffer(4) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    ushort4 retrievedCounts = counts16[id];
    
    ushort3 partialSums;
    partialSums.xz = retrievedCounts.xz + retrievedCounts.yw;
    partialSums.yz = ushort2(partialSums.x) + ushort2(retrievedCounts.z, partialSums.z);
    
    counts64[id] = partialSums.z;
    offsets16[id] = { 0, retrievedCounts.x, partialSums.x, partialSums.y };
}



kernel void markNanoSector16to4OffsetsForMatch(device ushort3 *counts_in   [[ buffer(2) ]],
                                               device ushort4 *offsets_out [[ buffer(3) ]],
                                               device ushort  *offsets_in  [[ buffer(4) ]],
                                               
                                               uint id [[ thread_position_in_grid ]])
{
    ushort3 retrievedCounts = counts_in[id];
    
    ushort4 offsets = { offsets_in[id] };
    offsets.y = offsets.x + retrievedCounts.x;
    offsets.z = offsets.y + retrievedCounts.y;
    offsets.w = offsets.z + retrievedCounts.z;
    
    offsets_out[id] = offsets;
}

kernel void markNanoSector1OffsetsForMatch(device uchar3  *counts4th         [[ buffer(1) ]],
                                           device ushort4 *offsets4th        [[ buffer(2) ]],
                                           device ushort  *offsetsIndividual [[ buffer(3) ]],
                                           device bool    *microSectorMarks  [[ buffer(15) ]],
                                           
                                           uint id [[ thread_position_in_grid ]])
{
    if (!microSectorMarks[id])
    {
        return;
    }
    
    ushort3 retrievedCounts = ushort3(counts4th[id]);
    
    ushort4 offsets = { offsetsIndividual[id] };
    offsets.y = offsets.x + retrievedCounts.x;
    offsets.z = offsets.y + retrievedCounts.y;
    offsets.w = offsets.z + retrievedCounts.z;
    
    offsets4th[id] = offsets;
}

kernel void markNanoSector16thOffsetsForMatch(device uchar  *offsets16th      [[ buffer(0) ]],
                                              device uchar  *counts4th        [[ buffer(1) ]],
                                              device ushort *offsets4th       [[ buffer(2) ]],
                                              
                                              device bool   *microSectorMarks [[ buffer(15) ]],
                                              device uint   *nanoSectorMarks  [[ buffer(16) ]],
                                              device ushort *offsets512th     [[ buffer(18) ]],
                                              
                                              uint id [[ thread_position_in_grid ]])
{
    if (!microSectorMarks[id >> 4])
    {
        return;
    }
    
    uint id_4th = id >> 2;
    
    if (counts4th[id_4th] == 0)
    {
        return;
    }
    
    ushort offset16 = offsets4th[id_4th] + offsets16th[id];
    uint retrievedMarks = nanoSectorMarks[id];
    
    auto offsetPointer = offsets512th + (id << 5);
    
    for (ushort i = 0; i < 32; ++i)
    {
        if ((retrievedMarks & 1) != 0)
        {
            offsetPointer[i] = offset16;
            ++offset16;
        }
        
        retrievedMarks >>= 1;
    }
}



kernel void clearNanoSectorColors(device ulong4 *nanoSectorColors [[ buffer(19) ]],
                                  
                                  uint id [[ thread_position_in_grid ]])
{
    nanoSectorColors[id] = ulong4(0);
}

kernel void divideNanoSectorColors(device half4 *nanoSectorColors [[ buffer(19) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    auto selectedColorPointer = nanoSectorColors + (id << 3);
    
    half count = selectedColorPointer->x;
    if (count == 0) { return; }
    
    half3 YCbCr = selectedColorPointer->yzw;
    YCbCr *= fast::divide(1, float(count));
    YCbCr = min(1, YCbCr);
    
    *selectedColorPointer = half4(as_type<half>(ushort(1)), YCbCr);
    
    for (ushort i = 1; i < 8; ++i)
    {
        half4 retrievedColor = selectedColorPointer[i];
        
        half count = retrievedColor.x;
        auto YCbCr = retrievedColor.yzw;
        
        if (any(isinf(YCbCr)))
        {
            selectedColorPointer->x = 0;
            return;
        }
        else
        {
            YCbCr *= fast::divide(1, float(count));
            YCbCr = min(1, YCbCr);
        }
        
        selectedColorPointer[i] = half4(count, YCbCr);
    }
}



kernel void markNanoSectorColors(device   uint4       *oldReducedColorBuffer      [[ buffer(0) ]],
                                 device   uint3       *oldReducedIndexBuffer      [[ buffer(1) ]],
                                 device   float3      *oldReducedVertexBuffer     [[ buffer(2) ]],
                                 device   uchar       *oldRasterizationComponents [[ buffer(4) ]],
                                 
                                 constant bool        &using8bitSmallSectorIDs    [[ buffer(10) ]],
                                 device   uchar       *smallSectorIDs             [[ buffer(11) ]],
                                 
                                 device   ushort      *oldMicroSectorLocations    [[ buffer(12) ]],
                                 device   ushort2     *oldMicroSectorCounts512th  [[ buffer(13) ]],
                                 
                                 constant uchar4      *oldSmallSectorMarks        [[ buffer(14) ]],
                                 device   uchar       *oldMicroSectorMarks        [[ buffer(15) ]],
                                 device   uchar       *oldNanoSectorMarks         [[ buffer(16) ]],
                                 
                                 device   uint        *oldMicroSectorOffsets64    [[ buffer(17) ]],
                                 device   ushort      *oldNanoSectorOffsets       [[ buffer(18) ]],
                                 device   atomic_uint *oldNanoSectorColors        [[ buffer(19) ]],
                                 
                                 uint id [[ thread_position_in_grid ]])
{
    ushort oldSmallSectorLocation = using8bitSmallSectorIDs ? smallSectorIDs [id]
                           : reinterpret_cast<device ushort*>(smallSectorIDs)[id];
    
    uchar retrievedMark = *reinterpret_cast<constant uchar*>(oldSmallSectorMarks + oldSmallSectorLocation);
    
    if (retrievedMark == 0)
    {
        return;
    }
    
    uint4 retrievedColor = oldReducedColorBuffer[id];

    if ((retrievedColor.x & 0x80000000) != 0)
    {
        return;
    }
    
    
    
    ushort winding = oldRasterizationComponents[id << 4];
    Range<true> range(oldReducedVertexBuffer, oldReducedIndexBuffer[id], winding);
    
    half2 chromaArray[4];
    half  lumaArray[4];
    
    for (uchar i = 0; i < 4; ++i)
    {
        chromaArray[i] = half2(as_type<uchar4>(retrievedColor[i]).gr) * (1.0 / 255);
        lumaArray  [i] = half (as_type<uchar4>(retrievedColor[i]).b ) * (1.0 / 255);
    }
    
    bool shouldStopMicroSector;
    uint oldExpandedMicroSectorBase = uint(oldSmallSectorLocation) << 9;
    uint oldExpandedNanoSectorBase;
    
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
                ushort oldMicroSectorLocation = oldMicroSectorLocations[oldExpandedMicroSectorID];
                oldExpandedNanoSectorBase = uint(oldMicroSectorLocation) << 9;
                
                shouldStopMicroSector = oldMicroSectorMarks[oldMicroSectorLocation] == 0;
            }
            else
            {
                shouldStopMicroSector = true;
            }
        }

        if (!shouldStopMicroSector)
        {
            uint oldNanoSectorLocation = oldExpandedNanoSectorBase + range.getNanoSectorID();
            
            ushort mask = 1 << (oldNanoSectorLocation & 7);
            ushort retrievedMark = reinterpret_cast<device uchar*>(oldNanoSectorMarks)[oldNanoSectorLocation >> 3] & mask;
            
            if (retrievedMark != 0)
            {
                uint nanoSectorOffset = oldMicroSectorOffsets64[oldExpandedNanoSectorBase >> 15]
                                      + oldNanoSectorOffsets   [oldNanoSectorLocation];
                
                auto selectedNanoSectorColors = oldNanoSectorColors + (nanoSectorOffset << 4);
                
                range.contributeColor(chromaArray, lumaArray, selectedNanoSectorColors);
            }
        }
        
        if (!range.increment())
        {
            return;
        }
    }
}



kernel void executeSecondMeshMatch(device   uint4   *newReducedColorBuffer            [[ buffer(0) ]],
                                   device   uint3   *newReducedIndexBuffer            [[ buffer(1) ]],
                                   device   float3  *newReducedVertexBuffer           [[ buffer(2) ]],
                                   device   uint    *newToOldTriangleMatches          [[ buffer(3) ]],
                                   device   uchar   *newRasterizationComponents       [[ buffer(4) ]],
                                   
                                   device   bool    &shouldDoThirdMatch               [[ buffer(5) ]],
                                   constant ushort  &numNewSmallSectorsMinus1         [[ buffer(6) ]],
                                   constant ushort  *newSmallSectorMappings           [[ buffer(7) ]],
                                   constant uint    *newSmallSectorSortedHashes       [[ buffer(8) ]],
                                   constant ushort  *newSmallSectorSortedHashMappings [[ buffer(9) ]],
                                   
                                   device   ushort  *oldMicroSectorLocations          [[ buffer(12) ]],
                                   device   ushort2 *oldMicroSectorCounts512th        [[ buffer(13) ]],
                                   
                                   device   uint    *oldMicroSectorOffsets64          [[ buffer(17) ]],
                                   device   ushort  *oldNanoSectorOffsets             [[ buffer(18) ]],
                                   device   half4   *oldNanoSectorColors              [[ buffer(19) ]],
                                   
                                   uint id [[ thread_position_in_grid ]])
{
    uint byteID = (id << 2) + 3;
    
    if (reinterpret_cast<device uchar*>(newToOldTriangleMatches)[byteID] < 255)
    {
        return;
    }
    
    ushort winding = newRasterizationComponents[id << 4];
    Range<true> range(newReducedVertexBuffer, newReducedIndexBuffer[id], winding);
    
    uint smallSectorHash = range.getSmallSectorHash();
    ushort hashLocation = BinarySearch::binarySearch(smallSectorHash, newSmallSectorSortedHashes,
                                                     numNewSmallSectorsMinus1);
    
    ushort newSmallSectorLocation = newSmallSectorSortedHashMappings[hashLocation];
    ushort oldSmallSectorLocation = newSmallSectorMappings[newSmallSectorLocation];
    
    
    
    half4 accumulatedColor_array[4] = { 0, 0, 0, 0 };
    
    bool shouldStopMicroSector;
    uint oldExpandedMicroSectorBase = uint(oldSmallSectorLocation) << 9;
    uint oldExpandedNanoSectorBase;
    
    ushort microSectorID_inSmallSector = __UINT16_MAX__;
    
    while (true)
    {
        ushort newMicroSectorID_inSmallSector = range.getMicroSectorID();
        
        if (newMicroSectorID_inSmallSector != microSectorID_inSmallSector)
        {
            microSectorID_inSmallSector = newMicroSectorID_inSmallSector;
            
            uint oldExpandedMicroSectorID = oldExpandedMicroSectorBase + microSectorID_inSmallSector;
            shouldStopMicroSector = oldMicroSectorCounts512th[oldExpandedMicroSectorID].x == 0;
            
            if (!shouldStopMicroSector)
            {
                ushort oldMicroSectorLocation = oldMicroSectorLocations[oldExpandedMicroSectorID];
                oldExpandedNanoSectorBase = uint(oldMicroSectorLocation) << 9;
            }
        }
        
        if (!shouldStopMicroSector)
        {
            uint oldNanoSectorLocation = oldExpandedNanoSectorBase + range.getNanoSectorID();
            
            uint nanoSectorOffset = oldMicroSectorOffsets64[oldExpandedNanoSectorBase >> 15]
                                  + oldNanoSectorOffsets   [oldNanoSectorLocation];

            auto selectedColorPointer = oldNanoSectorColors + (nanoSectorOffset << 3);

            if (*reinterpret_cast<device uchar*>(selectedColorPointer) == 1)
            {
                range.addColor(selectedColorPointer, accumulatedColor_array);
            }
        }
        
        if (!range.increment())
        {
            if (accumulatedColor_array[0].x == 0)
            {
                if (!shouldDoThirdMatch)
                {
                    shouldDoThirdMatch = true;
                }
            }
            else
            {
                uint4 output;
                
                for (uchar i = 0; i < 4; ++i)
                {
                    half3 YCbCr = accumulatedColor_array[i].yzw;
                    YCbCr *= fast::divide(1, float(accumulatedColor_array[i].x));
                    YCbCr  = min(1, YCbCr);
                    
                    uchar3 CrCbY = uchar3(rint(YCbCr.bgr * 255));
                    output[i] = as_type<uint>(uchar4(CrCbY, 0));
                }
                
                newReducedColorBuffer[id] = output;
                newToOldTriangleMatches[id] = 254 << 24;
            }
            
            return;
        }
    }
}
#endif

//
//  ThirdSceneMeshMatchTypes.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/22/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "../../../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

class Location {
    char3 smallSector;
    char3 microSector;
    char3 nanoSector;
    
private:
    float3 startInitialization(float3 point)
    {
        float3 transformedPoint = floor(point * 0.5);
        smallSector = char3(transformedPoint);
        
        return float3(smallSector + smallSector);
    }
    
    void finishInitialization(float3 point, float3 smallSectorOrigin)
    {
        float3 microSectorOffset = point - smallSectorOrigin;
        microSectorOffset *= 4;
        
        microSector = char3(microSectorOffset);
        microSector = clamp(microSector, 0, 7);
        
        float3 microSectorOrigin = fma(float3(microSector), 0.25, smallSectorOrigin);
        float3 nanoSectorOffset  = point - microSectorOrigin;
        nanoSectorOffset *= 32;
        
        nanoSector = char3(nanoSectorOffset);
        nanoSector = clamp(nanoSector, 0, 7);
    }
    
public:
    Location()
    {
        
    }
    
    Location(float3 point)
    {
        float3 smallSectorOrigin = startInitialization(point);
        finishInitialization(point, smallSectorOrigin);
    }
    
    Location(float3 point, thread Location &other, float3 otherPoint)
    {
        float3 smallSectorOrigin = startInitialization(point);
              finishInitialization(point,      smallSectorOrigin);
        other.finishInitialization(otherPoint, smallSectorOrigin);
    }
    
    
    
    void roundUp(uchar notGranularityMinus1, uchar granularityMinus1)
    {
        nanoSector = notGranularityMinus1 & (nanoSector + granularityMinus1);
        
        if (any(nanoSector >= 8))
        {
            for (uchar i = 0; i < 3; ++i)
            {
                checkOverflow(i);
            }
        }
    }
    
    void roundDown(uchar notGranularityMinus1)
    {
        nanoSector = notGranularityMinus1 & nanoSector;
    }
    
    friend Location operator+(Location lhs, uchar rhs)
    {
        Location out = lhs;
        out.increaseCoords(rhs);
        
        return out;
    }
    
    friend Location operator-(Location lhs, uchar rhs)
    {
        Location out = lhs;
        out.decreaseCoords(rhs);
        
        return out;
    }
    
    
    
    uint getSmallSectorHash() const
    {
        uint hashX = as_type<uint>(int(smallSector.x)) & 2047;
        uint hashY = as_type<uint>(int(smallSector.y)) & 2047;
        uint hashZ = as_type<uint>(int(smallSector.z)) & 1023;
        
        return (hashX << 21) | (hashY << 10) | (hashZ);
    }
    
    ushort getMicroSectorID() const
    {
        ushort   x_id = ushort (as_type<uchar> (microSector.x))  << 6;
        ushort2 yz_id = ushort2(as_type<uchar2>(microSector.yz)) << ushort2(3, 0);
        
        return x_id | yz_id[0] | yz_id[1];
    }
    
    uchar getSubMicroSectorID(ushort granularityPowerOf2) const
    {
        short3 hashes = short3(nanoSector) >> granularityPowerOf2;
        
        hashes.xy <<= ushort2(3 - granularityPowerOf2) << ushort2(1, 0);

        return hashes.x | hashes.y | hashes.z;
    }
    
    
    
    template <bool usingExpandedBounds>
    void copyCoords(Location other, ushort index)
    {
        if (usingExpandedBounds)
        {
            smallSector[index] = other.smallSector[index];
        }
        
        microSector[index] = other.microSector[index];
        nanoSector [index] = other.nanoSector [index];
    }
    
    void copyNoSmallSector(Location other)
    {
        microSector = other.microSector;
        nanoSector  = other.nanoSector;
    }
    
    template <bool usingExpandedBounds>
    void increaseCoord(ushort index, uchar changeMagnitude)
    {
        nanoSector[index] += changeMagnitude;
        
        if (nanoSector[index] >= 8)
        {
            nanoSector[index] -= 8;
            ++microSector[index];
            
            if (usingExpandedBounds && microSector[index] >= 8)
            {
                microSector[index]= 0;
                ++smallSector[index];
            }
        }
    }
    
    template <bool usingExpandedBounds>
    bool lessOrEqual(Location other, ushort index) const
    {
        if (usingExpandedBounds)
        {
            if      (smallSector[index] < other.smallSector[index]) { return true;  }
            else if (smallSector[index] > other.smallSector[index]) { return false; }
        }
        
        if      (microSector[index] < other.microSector[index]) { return true;  }
        else if (microSector[index] > other.microSector[index]) { return false; }
        
        return nanoSector[index] <= other.nanoSector[index];
    }
    
    float3 getLocationCenter(ushort granularity) const
    {
        float3 output = float3(smallSector + smallSector);
        output += float(granularity) * (0.5 * 0.03125);
        
        output = fma(float3(microSector), 0.25,    output);
        output = fma(float3(nanoSector),  0.03125, output);
        
        return output;
    }
    
private:
    void checkOverflow(ushort index)
    {
        if (nanoSector[index] >= 8)
        {
            nanoSector[index] -= 8;
            ++microSector[index];
            
            if (microSector[index] >= 8)
            {
                microSector[index] = 0;
                ++smallSector[index];
            }
        }
    }
    
    void checkUnderflow(ushort index)
    {
        if (nanoSector[index] < 0)
        {
            nanoSector[index] += 8;
            --microSector[index];
            
            if (microSector[index] < 0)
            {
                microSector[index] = 7;
                --smallSector[index];
            }
        }
    }
    
    
    
    void increaseCoords(uchar changeMagnitude)
    {
        nanoSector += changeMagnitude;
        
        if (any(nanoSector >= 8))
        {
            for (ushort i = 0; i < 3; ++i)
            {
                checkOverflow(i);
            }
        }
    }
    
    void decreaseCoords(uchar changeMagnitude)
    {
        nanoSector -= changeMagnitude;
        
        if (any(nanoSector < 0))
        {
            for (ushort i = 0; i < 3; ++i)
            {
                checkUnderflow(i);
            }
        }
    }
};



template <bool usingExpandedBounds>
class Range {
    Location originalStart;
    Location originalEnd;
    
    Location start;
    Location end;
    Location iterator;
    
    float3 center;
    ushort granularityPowerOf2;
    
public:
    Range(device float3 *vertexBuffer, uint3 indices)
    {
        float3 vertexA = vertexBuffer[indices[0]];
        float3 vertexB = vertexBuffer[indices[1]];
        float3 vertexC = vertexBuffer[indices[2]];
        
        center = (vertexA + vertexB + vertexC) * float(1.0 / 3);
        
        if (usingExpandedBounds)
        {
            originalStart = Location(min3(vertexA, vertexB, vertexC));
            originalEnd   = Location(max3(vertexA, vertexB, vertexC));
        }
        else
        {
            float3 vertexMin = min3(vertexA, vertexB, vertexC);
            float3 vertexMax = max3(vertexA, vertexB, vertexC);
            
            originalStart = Location(vertexMin, originalEnd, vertexMax);
        }
        
        granularityPowerOf2 = 1;
        processGranularityChange<true>();
    }
    
    bool increment()
    {
        if (incrementBody()) { return true; }
        
        granularityPowerOf2 += 1;
        if (granularityPowerOf2 > 3) { return false; }
        
        processGranularityChange<false>();
        return true;
    }
    
    bool incrementWithColor(half accumulatedColorX)
    {
        if (incrementBody())        { return true; }
        if (accumulatedColorX != 0) { return false; }
        
        granularityPowerOf2 += 1;
        if (granularityPowerOf2 > 3) { return false; }
        
        processGranularityChange<false>();
        return true;
    }
    
    uint   getSmallSectorHash()     const { return iterator.getSmallSectorHash(); }
    ushort getMicroSectorID()       const { return iterator.getMicroSectorID(); }
    ushort getSubMicroSectorID()    const { return iterator.getSubMicroSectorID(granularityPowerOf2); }
    ushort getGranularityPowerOf2() const { return granularityPowerOf2; }
    
    void contributeColor(half2 chroma, half luma, device atomic_uint *sectorColors) const
    {
        half closeness = getCloseness();
        
        half2 contributions[2];
        contributions[0] = half2(closeness, luma * closeness);
        contributions[1] = chroma * closeness;
        
        addContributions(contributions, sectorColors);
    }
    
    void addColor(thread half4 retrievedColor, thread half4 &accumulatedColor) const
    {
        if (retrievedColor.x == 0 || any(isinf(retrievedColor)))
        {
            return;
        }
        
        half closeness = getCloseness();
        retrievedColor.x = fast::divide(1, float(retrievedColor.x));
        
        half3 YCbCr = retrievedColor.yzw * retrievedColor.x;
        accumulatedColor = fma(half4(1, YCbCr), closeness, accumulatedColor);
    }
    
private:
    bool incrementBody()
    {
        uchar granularity = 1 << granularityPowerOf2;

        for (ushort i = 0; i < 2; ++i)
        {
            iterator.increaseCoord<usingExpandedBounds>(i, granularity);
            if (iterator.lessOrEqual<usingExpandedBounds>(end, i)) { return true; }
            
            iterator.copyCoords<usingExpandedBounds>(start, i);
        }
        
        iterator.increaseCoord<usingExpandedBounds>(2, granularity);
        return iterator.lessOrEqual<usingExpandedBounds>(end, 2);
    }
    
    template <bool initializingIterator>
    void processGranularityChange()
    {
        ushort granularity = 1 << granularityPowerOf2;
        
        uchar granularityMinus1 = granularity - 1;
        uchar notGranularityMinus1 = ~granularityMinus1;
        
        if (usingExpandedBounds)
        {
            start = originalStart - granularity;
            end   = originalEnd   + granularity;
            
            end.roundUp(notGranularityMinus1, granularityMinus1);
        }
        else
        {
            start = originalStart;
            end   = originalEnd;
            
            end.roundDown(notGranularityMinus1);
        }
        
        start.roundDown(notGranularityMinus1);
        
        if (initializingIterator || usingExpandedBounds)
        {
            iterator = start;
        }
        else
        {
            iterator.copyNoSmallSector(start);
        }
    }
    
    half getCloseness() const
    {
        float3 iteratorCenter = iterator.getLocationCenter(1 << granularityPowerOf2);
        half3 centerDelta = half3(iteratorCenter - center);
        
        centerDelta *= half(1 << (5 - granularityPowerOf2));
        
        float closeness = fast::divide(1, length_squared(centerDelta));
        return clamp(half(closeness), half(1.0 / 32), half(64));
    }
    
    void addContributions(thread half2 *contributions, device atomic_uint *firstTarget) const
    {
        auto secondTarget = firstTarget + 1;
        
        bool2 successes(ColorUtilities::attemptAtomicallyAddHalf(contributions[0], firstTarget),
                        ColorUtilities::attemptAtomicallyAddHalf(contributions[1], secondTarget));
        
        while (!all(successes))
        {
            if (!successes[0]) { successes[0] = ColorUtilities::attemptAtomicallyAddHalf(contributions[0], firstTarget); }
            if (!successes[1]) { successes[1] = ColorUtilities::attemptAtomicallyAddHalf(contributions[1], secondTarget); }
        }
    }
};
#endif

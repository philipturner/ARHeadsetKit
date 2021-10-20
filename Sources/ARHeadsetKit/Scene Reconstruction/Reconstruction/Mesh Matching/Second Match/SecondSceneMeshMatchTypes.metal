//
//  SecondSceneMeshMatchTypes.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "../../../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

class Location {
    char3 microSector;
    char3 nanoSector;
    
public:
    Location()
    {

    }
    
    Location(float3 point, char3 inputSmallSector)
    {
        float3 transformedPoint = floor(point * 0.5);
        char3 smallSector = char3(transformedPoint);
        
        float3 smallSectorOrigin = float3(smallSector + smallSector);
        float3 microSectorOffset = point - smallSectorOrigin;
        microSectorOffset *= 4;
        
        microSector = char3(microSectorOffset);
        microSector = clamp(microSector, 0, 7);
        
        float3 microSectorOrigin = fma(float3(microSector), 0.25, smallSectorOrigin);
        float3 nanoSectorOffset  = point - microSectorOrigin;
        nanoSectorOffset *= 32;
        
        nanoSector = char3(nanoSectorOffset);
        nanoSector = clamp(nanoSector, 0, 7);
        
        if (any(smallSector != inputSmallSector))
        {
            for (uchar i = 0; i < 3; ++i)
            {
                if (smallSector[i] == inputSmallSector[i])
                {
                    continue;
                }
                
                if (smallSector[i] < inputSmallSector[i])
                {
                    microSector[i] = 0;
                    nanoSector [i] = 0;
                }
                else
                {
                    microSector[i] = 7;
                    nanoSector [i] = 7;
                }
            }
        }
    }
    
    ushort getMicroSectorID() const
    {
        ushort   x_id = ushort (as_type<uchar> (microSector.x))  << 6;
        ushort2 yz_id = ushort2(as_type<uchar2>(microSector.yz)) << ushort2(3, 0);
        
        return x_id | yz_id[0] | yz_id[1];
    }
    
    ushort getNanoSectorID() const
    {
        ushort   x_id = ushort (as_type<uchar> (nanoSector.x))  << 6;
        ushort2 yz_id = ushort2(as_type<uchar2>(nanoSector.yz)) << ushort2(3, 0);
        
        return x_id | yz_id[0] | yz_id[1];
    }
    
    void copyCoords(Location other, ushort index)
    {
        microSector[index] = other.microSector[index];
        nanoSector [index] = other.nanoSector [index];
    }
    
    void incrementCoord(ushort index)
    {
        ++nanoSector[index];
        
        if (nanoSector[index] >= 8)
        {
            nanoSector[index] = 0;
            ++microSector[index];
        }
    }
    
    bool lessOrEqual(Location other, ushort index) const
    {
        if      (microSector[index] < other.microSector[index]) { return true;  }
        else if (microSector[index] > other.microSector[index]) { return false; }
        
        return nanoSector[index] <= other.nanoSector[index];
    }
    
    float3 getLocationCorner(char3 smallSector) const
    {
        float3 output = float3(smallSector + smallSector);
        
        output = fma(float3(microSector), 0.25,    output);
        output = fma(float3(nanoSector),  0.03125, output);
        
        return output;
    }
};



template <bool samplingColor>
class Range {
    Location start;
    Location end;
    Location iterator;
    
    float3 center;
    half3 cornerDeltas[3];
    char3 smallSector;
    
public:
    Range(device float3 *vertexBuffer, uint3 indices, ushort winding = -1)
    {
        float3 vertexA = vertexBuffer[indices[0]];
        float3 vertexB = vertexBuffer[indices[1]];
        float3 vertexC = vertexBuffer[indices[2]];
        
        center = (vertexA + vertexB + vertexC) * float(1.0 / 3);
        smallSector = char3(floor(center * 0.5));
        
        start = Location(min3(vertexA, vertexB, vertexC), smallSector);
        end   = Location(max3(vertexA, vertexB, vertexC), smallSector);
        
        iterator = start;
        
        if (samplingColor)
        {
            vertexA -= center;
            vertexB -= center;
            vertexC -= center;
            
            if (winding == 0)
            {
                cornerDeltas[0] = half3(vertexA);
                cornerDeltas[1] = half3(vertexB);
                cornerDeltas[2] = half3(vertexC);
            }
            else if (winding == 1)
            {
                cornerDeltas[0] = half3(vertexB);
                cornerDeltas[1] = half3(vertexC);
                cornerDeltas[2] = half3(vertexA);
            }
            else
            {
                cornerDeltas[0] = half3(vertexC);
                cornerDeltas[1] = half3(vertexA);
                cornerDeltas[2] = half3(vertexB);
            }
            
            for (uchar i = 0; i < 3; ++i)
            {
                cornerDeltas[i] *= 0.5 * 32;
            }
        }
    }
    
    bool increment()
    {
        for (ushort i = 0; i < 2; ++i)
        {
            iterator.incrementCoord(i);
            if (iterator.lessOrEqual(end, i)) { return true; }
            
            iterator.copyCoords(start, i);
        }
        
        iterator.incrementCoord(2);
        return iterator.lessOrEqual(end, 2);
    }
    
    uint getSmallSectorHash() const
    {
        uint hashX = as_type<uint>(int(smallSector.x)) & 2047;
        uint hashY = as_type<uint>(int(smallSector.y)) & 2047;
        uint hashZ = as_type<uint>(int(smallSector.z)) & 1023;
        
        return (hashX << 21) | (hashY << 10) | (hashZ);
    }
    
    ushort getMicroSectorID() const { return iterator.getMicroSectorID(); }
    ushort getNanoSectorID()  const { return iterator.getNanoSectorID(); }
    
    void contributeColor(thread half2 *chroma, thread half *luma, device atomic_uint *nanoSectorColors) const
    {
        half3 cornerDelta_times32 = getCornerDelta() * 32;
        
        for (ushort i = 0; i < 8; ++i)
        {
            half3 subsectorDelta = cornerDelta_times32 + getSubsectorDelta(i);
            
            half4 closenesses(getCloseness2(subsectorDelta, 0,
                                            subsectorDelta, 1),
                              getCloseness2(subsectorDelta, 2,
                                            subsectorDelta, 3));
            
            half2 contributions[2];
            
            for (uchar j = 0; j < 4; ++j)
            {
                if (j == 0)
                {
                    contributions[0] = { closenesses[j], luma[j] * closenesses[j] };
                    contributions[1] = chroma[j] * closenesses[j];
                }
                else
                {
                    contributions[0] += { closenesses[j], luma[j] * closenesses[j] };
                    contributions[1] += chroma[j] * closenesses[j];
                }
            }
            
            addContributions(contributions, nanoSectorColors + (i << 1));
        }
    }
    
    void addColor(device half4 *selectedColorPointer, thread half4 *accumulatedColor) const
    {
        half3 cornerDelta_times32 = getCornerDelta() * 32;
        
        for (ushort i = 0; i < 8; ++i)
        {
            half3 subsectorDelta = cornerDelta_times32 + getSubsectorDelta(i);
            half3 YCbCr = selectedColorPointer[i].yzw;
            
            half4 closenesses(getCloseness2(subsectorDelta, 0,
                                            subsectorDelta, 1),
                              getCloseness2(subsectorDelta, 2,
                                            subsectorDelta, 3));
            
            for (uchar j = 0; j < 4; ++j)
            {
                accumulatedColor[j] = fma(half4(1, YCbCr), closenesses[j], accumulatedColor[j]);
            }
        }
    }
    
private:
    half3 getCornerDelta() const
    {
        return half3(iterator.getLocationCorner(smallSector) - center);
    }
    
    half3 getSubsectorDelta(ushort subsectorID) const
    {
        return select(half3(0.25), half3(0.75), (subsectorID & ushort3(4, 2, 1)) != 0);
    }
    
    half2 getCloseness2(half3 delta1, ushort samplePoint1,
                        half3 delta2, ushort samplePoint2) const
    {
        half3 sampleDelta1 = (samplePoint1 == 0) ? delta1 : delta1 - cornerDeltas[samplePoint1 - 1];
        half3 sampleDelta2 = (samplePoint2 == 0) ? delta2 : delta2 - cornerDeltas[samplePoint2 - 1];
        
        half2 closenesses = 1 / half2(length_squared(sampleDelta1), length_squared(sampleDelta2));
        return clamp(closenesses, half2(1.0 / 32), half2(64));
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

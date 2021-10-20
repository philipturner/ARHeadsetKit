//
//  SceneTexelRasterization.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "../../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

kernel void rasterizeTexels(device   uint3  *triangleIndices            [[ buffer(0) ]],
                            constant float3 *vertices                   [[ buffer(1) ]],
                            constant uint   &triangleCount              [[ buffer(2) ]],
                            
                            device   uint4  *texelCounts                [[ buffer(3) ]],
                            device   uint4  *columnCounts               [[ buffer(4) ]],
                            device   ushort *texelCounts16              [[ buffer(5) ]],
                            device   ushort *columnCounts16             [[ buffer(6) ]],
                            
                            device   uint4  *haveChangedMarks           [[ buffer(7) ]],
                            device   ushort *compressedHaveChangedMarks [[ buffer(8) ]],
                            device   float4 *newRasterizationComponents [[ buffer(9) ]],
                            
                            device   uint   *newToOldTriangleMatches    [[ buffer(10) ]],
                            device   float4 *oldRasterizationComponents [[ buffer(11) ]],
                            device   uchar  *newToOldMatchWindings      [[ buffer(12) ]],
                            
                            uint id [[ thread_position_in_grid ]])
{
    uint i     = id << 4;
    uint i_end = min(i + 16, triangleCount);
    
    uint4 totalCachedTexelCounts;
    uint4 totalCachedColumnCounts;
    uint4 totalCachedHaveChangedMarks;
    
    ushort2 texelCountSum  = ushort2(0);
    ushort2 columnCountSum = ushort2(0);
    
    ushort totalCompressedHaveChangedMarks = 0;
    ushort totalIndex = 0;
    ushort mask = 1;
    
    while (i < i_end)
    {
        ushort4 cachedTexelCounts;
        ushort4 cachedColumnCounts;
        ushort4 cachedHaveChangedMarks(0);
        
        ushort j     = 0;
        ushort j_end = min(ushort(4), ushort(i_end - i));
        
        while (j < j_end)
        {
            uint triangleID = i + j;
            
            uint matchedOldTriangleID = newToOldTriangleMatches[triangleID];
            bool foundMatch = as_type<uchar4>(matchedOldTriangleID).w != 255;
            ushort oldWinding;
            
            if (foundMatch)
            {
                oldWinding = newToOldMatchWindings[triangleID];
                
                if ((oldWinding & 4) == 0)
                {
                    cachedHaveChangedMarks[j] = 1;
                    totalCompressedHaveChangedMarks |= mask;
                }
                
                ushort rasterizationWinding = as_type<uchar4>(oldRasterizationComponents[matchedOldTriangleID][3])[0];
                oldWinding = (3 + rasterizationWinding) - (oldWinding & 3);

                if (oldWinding >= 3)
                {
                    if      (oldWinding == 3) { oldWinding = 0; }
                    else if (oldWinding == 4) { oldWinding = 1; }
                    else                      { oldWinding = 2; }
                }
            }
            else
            {
                cachedHaveChangedMarks[j] = 1;
                totalCompressedHaveChangedMarks |= mask;
            }
            
            float longestSideLength;
            float parallelComponent;
            float orthogonalComponent;
            
            ushort winding;
            
            if (cachedHaveChangedMarks[j] == 0)
            {
                winding = oldWinding;
                
                float3 retrievedComponents = oldRasterizationComponents[matchedOldTriangleID].xyz;
                
                longestSideLength   = retrievedComponents.x;
                parallelComponent   = retrievedComponents.y;
                orthogonalComponent = retrievedComponents.z;
            }
            else
            {
                uint3 indices = triangleIndices[triangleID];
                
                float3 vertexA = vertices[indices.x];
                float3 vertexB = vertices[indices.y];
                float3 vertexC = vertices[indices.z];
                
                float3 sides[3] = {
                    vertexB - vertexA,
                    vertexC - vertexB,
                    vertexA - vertexC
                };
                
                float3 lengths_squared = {
                    length_squared(sides[0]),
                    length_squared(sides[1]),
                    length_squared(sides[2])
                };
                
                ushort sideIndex2;

#define SET_WINDING(a)                  \
winding    =  a;                        \
sideIndex2 = (a + 2) % 3;               \
                                        \
longestSideLength = lengths_squared[a]; \
                
                if (lengths_squared[0] >= lengths_squared[1])
                {
                    if (lengths_squared[0] >= lengths_squared[2]) { SET_WINDING(0); }
                    else                                          { SET_WINDING(2); }
                }
                else
                {
                    if (lengths_squared[1] >= lengths_squared[2]) { SET_WINDING(1); }
                    else                                          { SET_WINDING(2); }
                }
                
                longestSideLength = precise::sqrt(longestSideLength);
                
                if (foundMatch)
                {
                    if (winding != oldWinding)
                    {
                        newToOldTriangleMatches[triangleID] = 255 << 24;
                    }
                }
                
                float3 longestSide_normalized = precise::divide(sides[winding], longestSideLength);
                
                parallelComponent   =                dot(longestSide_normalized,                     -sides[sideIndex2]);
                orthogonalComponent = length_squared(fma(longestSide_normalized, -parallelComponent, -sides[sideIndex2]));
                orthogonalComponent = precise::sqrt(orthogonalComponent);
                
                longestSideLength   *= 128;
                parallelComponent   *= 128;
                orthogonalComponent *= 128;
                
                orthogonalComponent = max(orthogonalComponent, 0.95);
            }
            
            newRasterizationComponents[triangleID] = {
                longestSideLength,
                parallelComponent,
                orthogonalComponent,
                as_type<float>(uchar4(winding, 3 - winding, 0, 0))
            };
            
            // Count texels

            ushort columnCount = ceil(longestSideLength);
            columnCount = min(columnCount, ushort(14));
            
            ushort texelCount = 0;

            float left_slope  = precise::divide(orthogonalComponent, parallelComponent);
            float right_slope = precise::divide(orthogonalComponent, longestSideLength - parallelComponent);

            for (ushort k = 0; k < columnCount; ++k)
            {
                float k_f = float(k);
                float height_f;
                
                if (k_f <= parallelComponent)
                {
                    float k_f_plus_1 = float(k + 1);
                    
                    if (parallelComponent < k_f_plus_1)
                    {
                        height_f = orthogonalComponent;
                    }
                    else
                    {
                        height_f = k_f_plus_1 * left_slope;
                    }
                }
                else
                {
                    float remaining = longestSideLength - k_f;
                    height_f = remaining * right_slope;
                }
                
                ushort height = ushort(ceil(height_f));
                texelCount += min(height, ushort(12));
            }

            cachedTexelCounts [j] = texelCount;
            cachedColumnCounts[j] = columnCount;

            ++j;
            mask <<= 1;
        }

        for (; j < 4; ++j)
        {
            cachedTexelCounts [j] = 0;
            cachedColumnCounts[j] = 0;
        }
        
#define CONVERT_MARKS(a) as_type<uint>(uchar4(a))
        
        totalCachedTexelCounts     [totalIndex] = CONVERT_MARKS(cachedTexelCounts);
        totalCachedColumnCounts    [totalIndex] = CONVERT_MARKS(cachedColumnCounts);
        totalCachedHaveChangedMarks[totalIndex] = CONVERT_MARKS(cachedHaveChangedMarks);

        texelCountSum  += ushort2(cachedTexelCounts.xy)  + ushort2(cachedTexelCounts.zw);
        columnCountSum += ushort2(cachedColumnCounts.xy) + ushort2(cachedColumnCounts.zw);

        i += 4;
        ++totalIndex;
    }

    for (; totalIndex < 4; ++totalIndex)
    {
        totalCachedTexelCounts [totalIndex] = 0;
        totalCachedColumnCounts[totalIndex] = 0;
    }

    texelCounts     [id] = totalCachedTexelCounts;
    columnCounts    [id] = totalCachedColumnCounts;
    haveChangedMarks[id] = totalCachedHaveChangedMarks;

    texelCounts16 [id] =  texelCountSum.x +  texelCountSum.y;
    columnCounts16[id] = columnCountSum.x + columnCountSum.y;
    
    compressedHaveChangedMarks[id] = totalCompressedHaveChangedMarks;
}

kernel void countTexels64(device ushort4 *texelCounts16  [[ buffer(5) ]],
                          device ushort4 *columnCounts16 [[ buffer(6) ]],
                          
                          device ushort  *texelCounts64  [[ buffer(7) ]],
                          device ushort  *columnCounts64 [[ buffer(8) ]],
                          
                          uint id [[ thread_position_in_grid ]])
{
    ushort4 texelCounts  = texelCounts16 [id];
    ushort4 columnCounts = columnCounts16[id];
    
    texelCounts.xy  += texelCounts.zw;
    columnCounts.xy += columnCounts.zw;
    
    texelCounts[0]  += texelCounts[1];
    columnCounts[0] += columnCounts[1];
    
    texelCounts64 [id] = texelCounts[0];
    columnCounts64[id] = columnCounts[0];
}

kernel void scanTexels256(device ushort4 *texelCounts64   [[ buffer(7) ]],
                          device ushort4 *columnCounts64  [[ buffer(8) ]],
                          
                          device ushort  *texelCounts256  [[ buffer(9) ]],
                          device ushort  *columnCounts256 [[ buffer(10) ]],
                          
                          device ushort4 *texelOffsets64  [[ buffer(11) ]],
                          device ushort4 *columnOffsets64 [[ buffer(12) ]],
                          
                          uint id [[ thread_position_in_grid ]])
{
    ushort4 texelCounts  = texelCounts64 [id];
    ushort4 columnCounts = columnCounts64[id];
    
    ushort4 texelOffsets  = { 0 };
    ushort4 columnOffsets = { 0 };
    
    for (uchar i = 0; i < 3; ++i)
    {
        texelOffsets [i + 1] = texelOffsets [i] + texelCounts [i];
        columnOffsets[i + 1] = columnOffsets[i] + columnCounts[i];
    }
    
    texelOffsets64 [id] = texelOffsets;
    columnOffsets64[id] = columnOffsets;
    
    texelOffsets[3]  += texelCounts[3];
    columnOffsets[3] += columnCounts[3];
    
    texelCounts256 [id] = texelOffsets[3];
    columnCounts256[id] = columnOffsets[3];
}

kernel void countTexels1024(device ushort4 *texelCounts256   [[ buffer(9) ]],
                            device ushort4 *columnCounts256  [[ buffer(10) ]],
                            
                            device uint    *texelCounts1024  [[ buffer(11) ]],
                            device uint    *columnCounts1024 [[ buffer(12) ]],
                            
                            uint id [[ thread_position_in_grid ]])
{
    uint4 texelCounts = uint4(texelCounts256[id]);
    uint4 columnCounts = uint4(columnCounts256[id]);
    
    texelCounts.xy += texelCounts.zw;
    columnCounts.xy += columnCounts.zw;
    
    texelCounts[0]  += texelCounts[1];
    columnCounts[0] += columnCounts[1];
    
    texelCounts1024 [id] = texelCounts[0];
    columnCounts1024[id] = columnCounts[0];
}

kernel void countTexels4096(device uint4 *texelCounts1024  [[ buffer(11) ]],
                            device uint4 *columnCounts1024 [[ buffer(12) ]],
                            
                            device uint  *texelCounts4096  [[ buffer(13) ]],
                            device uint  *columnCounts4096 [[ buffer(14) ]],
                            
                            uint id [[ thread_position_in_grid ]])
{
    uint4 texelCounts  = texelCounts1024 [id];
    uint4 columnCounts = columnCounts1024[id];
    
    texelCounts.xy += texelCounts.zw;
    columnCounts.xy += columnCounts.zw;
    
    texelCounts[0]  += texelCounts[1];
    columnCounts[0] += columnCounts[1];
    
    texelCounts4096 [id] = texelCounts[0];
    columnCounts4096[id] = columnCounts[0];
}



kernel void markTexelOffsets4096(device uint3 *texelCounts1024   [[ buffer(0) ]],
                                 device uint3 *columnCounts1024  [[ buffer(1) ]],
                                 
                                 device uint  *texelOffsets4096  [[ buffer(2) ]],
                                 device uint  *columnOffsets4096 [[ buffer(3) ]],
                                       
                                 device uint4 *texelOffsets1024  [[ buffer(4) ]],
                                 device uint4 *columnOffsets1024 [[ buffer(5) ]],
                                       
                                 uint id [[ thread_position_in_grid ]])
{
    uint3 texelCounts  = texelCounts1024 [id];
    uint3 columnCounts = columnCounts1024[id];
    
    uint4 texelOffsets  = { texelOffsets4096 [id] };
    uint4 columnOffsets = { columnOffsets4096[id] };
    
    for (uchar i = 0; i < 3; ++i)
    {
        texelOffsets [i + 1] = texelOffsets [i] + texelCounts [i];
        columnOffsets[i + 1] = columnOffsets[i] + columnCounts[i];
    }
    
    texelOffsets1024 [id] = texelOffsets;
    columnOffsets1024[id] = columnOffsets;
}

kernel void markTexelOffsets1024(device ushort3 *texelCounts256    [[ buffer(2) ]],
                                 device ushort3 *columnCounts256   [[ buffer(3) ]],
                                 
                                 device uint    *texelOffsets1024  [[ buffer(4) ]],
                                 device uint    *columnOffsets1024 [[ buffer(5) ]],
                                 
                                 device uint4   *columnOffsets256  [[ buffer(6) ]],
                                 device uint4   *texelOffsets256   [[ buffer(7) ]],
                                       
                                 uint id [[ thread_position_in_grid ]])
{
    ushort3 texelCounts  = texelCounts256 [id];
    ushort3 columnCounts = columnCounts256[id];
    
    uint4 texelOffsets  = { texelOffsets1024 [id] };
    uint4 columnOffsets = { columnOffsets1024[id] };
    
    for (uchar i = 0; i < 3; ++i)
    {
        texelOffsets [i + 1] = texelOffsets [i] + texelCounts [i];
        columnOffsets[i + 1] = columnOffsets[i] + columnCounts[i];
    }
    
    texelOffsets256 [id] = texelOffsets;
    columnOffsets256[id] = columnOffsets;
}

kernel void markTexelOffsets64(device ushort3 *texelCounts16   [[ buffer(0) ]],
                               device ushort3 *columnCounts16  [[ buffer(1) ]],
                               
                               device ushort  *texelOffsets64  [[ buffer(2) ]],
                               device ushort  *columnOffsets64 [[ buffer(3) ]],
                               
                               device ushort4 *texelOffsets16  [[ buffer(4) ]],
                               device ushort4 *columnOffsets16 [[ buffer(5) ]],
                               
                               uint id [[ thread_position_in_grid ]])
{
    ushort3 texelCounts  = texelCounts16 [id];
    ushort3 columnCounts = columnCounts16[id];
    
    ushort4 texelOffsets  = { texelOffsets64 [id] };
    ushort4 columnOffsets = { columnOffsets64[id] };
    
    for (uchar i = 0; i < 3; ++i)
    {
        texelOffsets [i + 1] = texelOffsets [i] + texelCounts [i];
        columnOffsets[i + 1] = columnOffsets[i] + columnCounts[i];
    }
    
    texelOffsets16 [id] = texelOffsets;
    columnOffsets16[id] = columnOffsets;
}

kernel void markTexelOffsets16(device   uchar4  *texelCounts                [[ buffer(0) ]],
                               device   uchar4  *columnCounts               [[ buffer(1) ]],
                               device   ushort4 *texelOffsets               [[ buffer(2) ]],
                               device   ushort4 *columnOffsets              [[ buffer(3) ]],
                               
                               device   ushort  *texelOffsets16             [[ buffer(4) ]],
                               device   ushort  *columnOffsets16            [[ buffer(5) ]],
                               constant uint    *columnOffsets256           [[ buffer(6) ]],
                               device   uchar   *expandedColumnOffsets      [[ buffer(7) ]],
                               
                               device   uint3   *triangleIndices            [[ buffer(8) ]],
                               constant float3  *vertices                   [[ buffer(9) ]],
                               constant uint    &triangleCount              [[ buffer(10) ]],
                               device   float3  *newRasterizationComponents [[ buffer(11) ]],
                               
                               uint id [[ thread_position_in_grid ]])
{
    uint i     = id << 4;
    uint i_end = min(i + 16, triangleCount);
    
    ushort texelOffset16  = texelOffsets16[id];
    ushort columnOffset16 = columnOffsets16[id];
    
    uint bufferOffset = columnOffsets256[id >> 4] + columnOffset16;
    
    for (; i < i_end; i += 4)
    {
        uint i_over_4 = i >> 2;
        ushort4 cachedTexelCounts  = ushort4(texelCounts [i_over_4]);
        ushort4 cachedColumnCounts = ushort4(columnCounts[i_over_4]);
        
        ushort4 cachedTexelOffsets;
        ushort4 cachedColumnOffsets;
        
        ushort j_end = min(ushort(4), ushort(i_end - i));
        
        for (ushort j = 0; j < j_end; ++j)
        {
            cachedTexelOffsets [j] = texelOffset16;
            cachedColumnOffsets[j] = columnOffset16;
            
            ushort texelCount  = cachedTexelCounts[j];
            ushort columnCount = cachedColumnCounts[j];
            
            texelOffset16  += texelCount;
            columnOffset16 += columnCount;
            
            float3 rasterizationComponents = newRasterizationComponents[i + j];

            float longestSideLength   = rasterizationComponents.x;
            float parallelComponent   = rasterizationComponents.y;
            float orthogonalComponent = rasterizationComponents.z;

            ushort expandedColumnOffset = 0;
            
            float left_slope  = precise::divide(orthogonalComponent, parallelComponent);
            float right_slope = precise::divide(orthogonalComponent, longestSideLength - parallelComponent);

            for (ushort k = 0; k < columnCount; ++k)
            {
                float k_f = float(k);
                float height_f;
                
                if (k_f <= parallelComponent)
                {
                    float k_f_plus_1 = float(k + 1);
                    
                    if (parallelComponent < k_f_plus_1)
                    {
                        height_f = orthogonalComponent;
                    }
                    else
                    {
                        height_f = k_f_plus_1 * left_slope;
                    }
                }
                else
                {
                    float remaining = longestSideLength - k_f;
                    height_f = remaining * right_slope;
                }
                
                ushort height = ushort(ceil(height_f));
                expandedColumnOffset += min(height, ushort(12));
                
                expandedColumnOffsets[bufferOffset] = expandedColumnOffset;
                ++bufferOffset;
            }
        }

        texelOffsets [i_over_4] = cachedTexelOffsets;
        columnOffsets[i_over_4] = cachedColumnOffsets;
    }
}



inline void purifyColor(thread uint4 &colors)
{
    if (as_type<uchar4>(colors[0]).w == 0)
    {
        colors[0] = as_type<uint>(as_type<uchar4>(colors[0]).bgra);
    }
    else
    {
        ushort numValidIDs = 0;
        ushort validIDs = 0;
        
        for (uchar i = 1; i < 4; ++i)
        {
            if (as_type<uchar4>(colors[i]).w == 0)
            {
                validIDs |= i << (numValidIDs << 1);
                ++numValidIDs;
            }
        }
        
        if (numValidIDs == 0)
        {
            colors[0] = as_type<uint>(uchar3(128, 128, 16).bgrr);
        }
        else if (numValidIDs == 3)
        {
            ushort3 sum = (ushort3(as_type<uchar4>(colors[1]).rgb)
                         + ushort3(as_type<uchar4>(colors[2]).rgb)
                         + ushort3(as_type<uchar4>(colors[3]).rgb));
            
            sum = (sum + 1) / 3;
            colors[0] = as_type<uint>(uchar4(uchar3(sum.bgr), 0));
        }
        else
        {
            ushort3 out;
            
            if (numValidIDs == 1)
            {
                out = ushort3(as_type<uchar4>(colors[validIDs]).rgb);
            }
            else
            {
                uint color1 = colors[validIDs & 3];
                
                out = hadd(ushort3(as_type<uchar4>(color1).rgb),
                           ushort3(as_type<uchar4>(colors[validIDs >> 2]).rgb));
            }
            
            colors[0] = as_type<uint>(uchar4(uchar3(out.bgr), 0));
        }
    }
    
    for (uchar i = 1; i < 4; ++i)
    {
        if (as_type<uchar4>(colors[i]).w == 0)
        {
            colors[i] = as_type<uint>(uchar4(as_type<uchar4>(colors[i]).bgr, 0));
        }
        else
        {
            colors[i] = colors[0];
        }
    }
}

inline void makeSamplePoints(thread half2 *samplePoints, half3 rasterizationComponents)
{
    samplePoints[5].x = (1.0 / 3) * rasterizationComponents.x;
    samplePoints[5].y = samplePoints[5].x + samplePoints[5].x;
    
    samplePoints[0].x = fma(half(1) / 3, rasterizationComponents.y, samplePoints[5].x);
    samplePoints[0].y = (1.0 / 3) * rasterizationComponents.z;
    
    samplePoints[1].x = 0.5 * samplePoints[0].x;
    samplePoints[1].y = 0.5 * samplePoints[0].y;
    
    samplePoints[2].x = 0.5 * (samplePoints[0].x + rasterizationComponents.x);
    
    samplePoints[3].x = 0.5 * (samplePoints[0].x + rasterizationComponents.y);
    samplePoints[3].y = samplePoints[0].y + samplePoints[0].y;
    
    samplePoints[4].x = 0.5 * rasterizationComponents.x;
    samplePoints[4].y = rasterizationComponents.x - rasterizationComponents.y;
}



inline uchar3 findInterpolation(half2 point, half3 rasterizationComponents, thread half2 *samplePoints, uint4 colors)
{
    ushort2 addTwoIndices;
    half2 addTwoSamplePoint = half2(samplePoints[2].x, samplePoints[1].y);
    
    bool addingThree = false;
    half addingThreeOperand;
    half distance_away_x_2;
    
    if (point.y < samplePoints[0].y)
    {
        addTwoIndices = { 1, 2 };
    }
    else if (point.x < samplePoints[4].x)
    {
        addTwoIndices = { 1, 3 };
        addTwoSamplePoint = samplePoints[3];
        
        if (point.x >= samplePoints[1].x)
        {
            distance_away_x_2 = point.x - samplePoints[1].x;
            addingThreeOperand = rasterizationComponents.y;
            addingThree = true;
        }
    }
    else
    {
        addTwoIndices = { 3, 2 };
        
        if (point.x <= samplePoints[2].x)
        {
            distance_away_x_2 = samplePoints[2].x - point.x;
            addingThreeOperand = samplePoints[4].y;
            addingThree = true;
        }
    }
    
    if (addingThree)
    {
        half distance_away_y_2 = point.y - samplePoints[1].y;
        
        if (fma(distance_away_y_2, addingThreeOperand, -(rasterizationComponents.z * distance_away_x_2)) > 0)
        {
            addingThree = false;
        }
        else
        {
            addTwoIndices = { 1, 2 };
            addTwoSamplePoint = half2(samplePoints[2].x, samplePoints[1].y);
        }
    }
    
    half4 weights = {
        distance_squared(point, samplePoints[0]),
        distance_squared(point, samplePoints[addTwoIndices[0]]),
        distance_squared(point, addTwoSamplePoint),
        distance_squared(point, samplePoints[3])
    };
    
    weights = clamp(1 / weights, half(1) / 1024, half(32));
    weights[0] += weights[0];
    
    half3 output = half3(as_type<uchar4>(colors[0]).rgb) * weights[0];
    
#define ADD_COLOR_BLOCK(index, weight)                                      \
output = fma(half3(as_type<uchar4>(colors[index]).rgb), weight, output);    \
    
    ADD_COLOR_BLOCK(addTwoIndices[0], weights[1]);
    ADD_COLOR_BLOCK(addTwoIndices[1], weights[2]);
    
    if (addingThree)
    {
        ADD_COLOR_BLOCK(3, weights[3]);
    }
    else
    {
        weights[3] = 0;
    }
    
    weights[0] += weights[2];
    weights[1] += weights[3];
    
    output *= fast::divide(1, weights[0] + weights[1]);
    
    return uchar3(output);
}

inline uchar3 findColor(ushort columnID, ushort rowID, half3 rasterizationComponents, thread half2 *samplePoints, uint4 color_uint)
{
    half2 point = half2(columnID, rowID) + half2(0.5);
    ushort colorIndex = 0;
    
    if (point.y > samplePoints[3].y)
    {
        colorIndex = 3;
    }
    else if (point.x < samplePoints[4].x)
    {
        if (fma(rasterizationComponents.z, samplePoints[5].x - point.x, -(point.y * samplePoints[4].y)) >= 0)
        {
            colorIndex = 1;
        }
    }
    else
    {
        if (fma(rasterizationComponents.z, point.x - samplePoints[5].y, -(point.y * rasterizationComponents.y)) >= 0)
        {
            colorIndex = 2;
        }
    }
    
    if (colorIndex != 0)
    {
        return as_type<uchar4>(color_uint[colorIndex]).rgb;
    }
    
    return findInterpolation(point, rasterizationComponents, samplePoints, color_uint);
}



kernel void transferColorDataToBuffer(device   uint    *newToOldTriangleMatches    [[ buffer(0) ]],
                                      device   uchar   *haveChangedMarks           [[ buffer(1) ]],
                                      device   uchar4  *newLumaBuffer              [[ buffer(2) ]],
                                      device   uchar2  *newChromaBuffer            [[ buffer(3) ]],
                                      
                                      device   uint4   *newReducedColors           [[ buffer(4) ]],
                                      device   uchar   *newTexelCounts             [[ buffer(5) ]],
                                      device   uchar   *newColumnCounts            [[ buffer(6) ]],
                                      device   ushort  *newTexelOffsets            [[ buffer(7) ]],
                                      device   ushort  *newColumnOffsets           [[ buffer(8) ]],
                                      constant uint    *newTexelOffsets256         [[ buffer(9) ]],
                                      constant uint    *newColumnOffsets256        [[ buffer(10) ]],
                                      device   uchar   *newExpandedColumnOffsets   [[ buffer(11) ]],
                                      device   float3  *newRasterizationComponents [[ buffer(12) ]],
                                      
                                      device   uint4   *oldReducedColors           [[ buffer(13) ]],
                                      device   ushort2 *oldTextureOffsets          [[ buffer(14) ]],
                                      device   uchar   *oldColumnCounts            [[ buffer(15) ]],
                                      device   ushort  *oldColumnOffsets           [[ buffer(16) ]],
                                      constant uint    *oldColumnOffsets256        [[ buffer(17) ]],
                                      device   uchar   *oldExpandedColumnOffsets   [[ buffer(18) ]],
                                      
                                      device   uchar2  *smallTriangleLumaRows      [[ buffer(19) ]],
                                      device   uchar2  *largeTriangleLumaRows      [[ buffer(20) ]],
                                      device   uchar2  *smallTriangleChromaRows    [[ buffer(21) ]],
                                      device   uchar2  *largeTriangleChromaRows    [[ buffer(22) ]],
                                      
                                      uint id [[ thread_position_in_grid ]])
{
    uint matchedTriangleID = newToOldTriangleMatches[id];

    if (haveChangedMarks[id] == 0)
    {
        newReducedColors[id] = oldReducedColors[matchedTriangleID];

        return;
    }
    
    uint newTexelOffset  = newTexelOffsets256[id >> 8] + newTexelOffsets[id];
    auto newLumaTexels   = newLumaBuffer   + newTexelOffset;
    auto newChromaTexels = newChromaBuffer + newTexelOffset;
    
    ushort errorCode = as_type<uchar4>(matchedTriangleID).w;
    uint4 color_uint;

    if (errorCode == 254)
    {
        color_uint = newReducedColors[id];
    }
    else
    {
        if (errorCode < 252)
        {
            color_uint = oldReducedColors[matchedTriangleID];
        }
        else
        {
            color_uint = uint4(as_type<uint>(uchar4(128, 128, 16, 128)));
        }

        newReducedColors[id] = color_uint;
    }
    
    if (errorCode >= 252 && errorCode != 254)
    {
        ushort texelCount = newTexelCounts[id];
        
        for (ushort i = 0; i < texelCount; ++i)
        {
            newLumaTexels[i]   = uchar4(16);
            newChromaTexels[i] = uchar2(128);
        }

        return;
    }
    
    purifyColor(color_uint);
    
    uint   newColumnOffset = newColumnOffsets[id] + newColumnOffsets256[id >> 8];
    ushort newColumnCount  = newColumnCounts[id];
    
    half3 rasterizationComponents = half3(newRasterizationComponents[id]);
    half2 samplePoints[6];
    
    makeSamplePoints(samplePoints, rasterizationComponents);
    
    ushort columnID = 0;
    ushort previousNewExpandedColumnOffset = 0;
    
    if (errorCode < 252)
    {
        device uchar2 *lumaRows;
        device uchar2 *chromaRows;
        
        ushort2 textureStart = oldTextureOffsets[matchedTriangleID];

        if (textureStart.y & 0x8000)
        {
            textureStart.y &= 0x7FFF;
            
            lumaRows   = largeTriangleLumaRows;
            chromaRows = largeTriangleChromaRows;
        }
        else
        {
            lumaRows   = smallTriangleLumaRows;
            chromaRows = smallTriangleChromaRows;
        }
        
        SceneColorReconstruction::YCbCrTexture texture(lumaRows, chromaRows);
        
        uint   oldColumnOffset = oldColumnOffsets[matchedTriangleID] + oldColumnOffsets256[matchedTriangleID >> 8];
        ushort oldColumnCount  = oldColumnCounts[matchedTriangleID];
        oldColumnCount = min(newColumnCount, oldColumnCount);
        
        ushort previousOldExpandedColumnOffset = 0;
        
        // Loop by column
        
        while (columnID < oldColumnCount)
        {
            ushort nextNewExpandedColumnOffset = newExpandedColumnOffsets[newColumnOffset + columnID];
            ushort nextOldExpandedColumnOffset = oldExpandedColumnOffsets[oldColumnOffset + columnID];

            ushort newTexelCount = nextNewExpandedColumnOffset - previousNewExpandedColumnOffset;
            ushort oldTexelCount = nextOldExpandedColumnOffset - previousOldExpandedColumnOffset;
            
            ushort nextOldExpandedColumnEnd = previousOldExpandedColumnOffset + min(newTexelCount, oldTexelCount);
            ushort2 chromaOffset = textureStart;
            
            // Loop by texel
            
            for (; previousOldExpandedColumnOffset < nextOldExpandedColumnEnd; ++previousOldExpandedColumnOffset)
            {
                auto texel = texture.read(chromaOffset);
                
                newLumaTexels  [previousNewExpandedColumnOffset] = texel.luma;
                newChromaTexels[previousNewExpandedColumnOffset] = texel.chroma;
                
                ++previousNewExpandedColumnOffset;
                ++chromaOffset.y;
            }

            previousOldExpandedColumnOffset = nextOldExpandedColumnOffset;
            ushort rowID = chromaOffset.y - textureStart.y;

            while (previousNewExpandedColumnOffset < nextNewExpandedColumnOffset)
            {
                uchar3 color = findColor(columnID, rowID, rasterizationComponents, samplePoints, color_uint);

                newLumaTexels  [previousNewExpandedColumnOffset] = uchar4(color.r);
                newChromaTexels[previousNewExpandedColumnOffset] = color.gb;

                ++previousNewExpandedColumnOffset;
                ++rowID;
            }

            ++columnID;
            ++textureStart.x;
        }
    }

    for (; columnID < newColumnCount; ++columnID)
    {
        ushort nextNewExpandedColumnOffset = newExpandedColumnOffsets[newColumnOffset + columnID];
        ushort rowID = 0;

        while (previousNewExpandedColumnOffset < nextNewExpandedColumnOffset)
        {
            uchar3 color = findColor(columnID, rowID, rasterizationComponents, samplePoints, color_uint);

            newLumaTexels  [previousNewExpandedColumnOffset] = uchar4(color.r);
            newChromaTexels[previousNewExpandedColumnOffset] = color.gb;

            ++previousNewExpandedColumnOffset;
            ++rowID;
        }
    }
}
#endif

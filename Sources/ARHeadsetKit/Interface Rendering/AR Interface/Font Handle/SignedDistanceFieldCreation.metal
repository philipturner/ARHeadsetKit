//
//  SignedDistanceFieldCreation.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/29/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
using namespace metal;

kernel void prepareTextBitmap(texture2d<ushort, access::sample> bitmap       [[ texture(0) ]],
                              texture2d<ushort, access::write>  mipmapLevels [[ texture(1) ]],

                              ushort2 id [[ thread_position_in_grid ]])
{
    constexpr sampler textureSampler(coord::pixel, filter::nearest);

    float2 texCoords = float2((id << 1) + 1);
    ushort4 retrievedMarks = bitmap.gather(textureSampler, texCoords);

    ushort output = select(0, 1, any(retrievedMarks == 255));
    output |= select(0, 2, any(retrievedMarks == 0));

    mipmapLevels.write(ushort4{ output }, id);
}

kernel void prepareTextMipmapLevels(texture2d<ushort, access::read_write> mipmapLevels    [[ texture(1) ]],
                                    texture2d<ushort, access::sample>     mipmapLevelsRef [[ texture(2) ]],
                                    
                                    ushort2 id [[ thread_position_in_grid ]])
{
    ushort numLevels = mipmapLevels.get_num_mip_levels();
    
    ushort2 startCoords = (id << numLevels) + 1;
    ushort2 endCoords   = (id + 1) << numLevels;
    
    for (; startCoords.x < endCoords.x; startCoords.x += 4)
    {
        ushort2 coords = startCoords;
        
        for (; coords.y < endCoords.y; coords.y += 4)
        {
            ushort4 retrievedMarks[4];
            float4 coords_float(float2(coords), float2(coords + 2));
            
            constexpr sampler textureSampler(coord::pixel, filter::nearest);
            retrievedMarks[0] = mipmapLevelsRef.gather(textureSampler, coords_float.xy);
            retrievedMarks[1] = mipmapLevelsRef.gather(textureSampler, coords_float.xw);
            retrievedMarks[2] = mipmapLevelsRef.gather(textureSampler, coords_float.zy);
            retrievedMarks[3] = mipmapLevelsRef.gather(textureSampler, coords_float.zw);
            
            ushort4 combinedMarks(
                retrievedMarks[0][0] | retrievedMarks[0][1],
                retrievedMarks[1][0] | retrievedMarks[1][1],
                retrievedMarks[2][0] | retrievedMarks[2][1],
                retrievedMarks[3][0] | retrievedMarks[3][1]
            );
            
            for (uchar i = 2; i < 4; ++i)
            {
                combinedMarks[0] |= retrievedMarks[0][i];
                combinedMarks[1] |= retrievedMarks[1][i];
                combinedMarks[2] |= retrievedMarks[2][i];
                combinedMarks[3] |= retrievedMarks[3][i];
            }
            
            ushort2 nextLevelCoords = coords >> 1;
            mipmapLevels.write(ushort4{ combinedMarks[0] }, nextLevelCoords | ushort2(0, 0), 1);
            mipmapLevels.write(ushort4{ combinedMarks[1] }, nextLevelCoords | ushort2(0, 1), 1);
            mipmapLevels.write(ushort4{ combinedMarks[2] }, nextLevelCoords | ushort2(1, 0), 1);
            mipmapLevels.write(ushort4{ combinedMarks[3] }, nextLevelCoords | ushort2(1, 1), 1);
            
            combinedMarks.xy |= combinedMarks.zw;
            combinedMarks[0] |= combinedMarks[1];
            
            mipmapLevels.write(ushort4{ combinedMarks[0] }, coords >> 2, 2);
        }
    }
    
    for (ushort h = 2; h < numLevels - 1; h += 2)
    {
        ushort coordPower = numLevels - h;
        
        ushort h_plus_1 = h + 1;
        ushort h_plus_2 = h + 2;
        
        ushort2 startCoords = id << coordPower;
        ushort2 endCoords   = (id + 1) << coordPower;
        
        for (; startCoords.x < endCoords.x; startCoords.x += 4)
        {
            ushort2 coords = startCoords;
            
            for (; coords.y < endCoords.y; coords.y += 4)
            {
                ushort4 output;
                ushort2 nextLevelCoords = coords >> 1;
                
#define READ_MIPMAP_BLOCK(i, j, k)                                                                  \
{                                                                                                   \
    output[k]  = mipmapLevels.read(coords | ushort2(i,     j    ), h).r;                            \
    output[k] |= mipmapLevels.read(coords | ushort2(i,     j + 1), h).r;                            \
    output[k] |= mipmapLevels.read(coords | ushort2(i + 1, j    ), h).r;                            \
    output[k] |= mipmapLevels.read(coords | ushort2(i + 1, j + 1), h).r;                            \
                                                                                                    \
    mipmapLevels.write(ushort4{ output[k] }, nextLevelCoords | ushort2(i / 2, j / 2), h_plus_1);    \
}                                                                                                   \
                
                READ_MIPMAP_BLOCK(0, 0, 0);
                READ_MIPMAP_BLOCK(0, 2, 1);
                READ_MIPMAP_BLOCK(2, 0, 2);
                READ_MIPMAP_BLOCK(2, 2, 3);
                
                output.xy |= output.zw;
                output[0] |= output[1];
                
                mipmapLevels.write(ushort4{ output[0] }, coords >> 2, h_plus_2);
            }
        }
    }
}



inline bool readCompressedBitmap(texture2d<ushort, access::read> compressedBitmap, ushort2 coords)
{
    return compressedBitmap.read(coords).r != 0;
}

inline bool sampleMipmapLevel(texture2d<ushort, access::read> mipmapLevels, ushort levelID_minus1,
                              ushort2 coords, ushort2 offset, ushort isInsideMask)
{
    ushort4 retrievedMasks;
    retrievedMasks[0] = mipmapLevels.read(ushort2(coords.x + offset.x, coords.y + offset.y), levelID_minus1).r;
    retrievedMasks[1] = mipmapLevels.read(ushort2(coords.x - offset.y, coords.y + offset.x), levelID_minus1).r;
    if (any(bool2(retrievedMasks.xy & isInsideMask))) { return true; }

    retrievedMasks[2] = mipmapLevels.read(ushort2(coords.x - offset.x, coords.y - offset.y), levelID_minus1).r;
    retrievedMasks[3] = mipmapLevels.read(ushort2(coords.x + offset.y, coords.y - offset.x), levelID_minus1).r;
    return any(bool2(retrievedMasks.zw & isInsideMask));
}

inline bool sampleCompressedBitmap(texture2d<ushort, access::read> bitmap, ushort2 coords, ushort2 offset, ushort isInsideMask)
{
    ushort4 retrievedMasks;
    retrievedMasks[0] = bitmap.read(ushort2(coords.x + offset.x, coords.y + offset.y)).r;
    retrievedMasks[1] = bitmap.read(ushort2(coords.x - offset.y, coords.y + offset.x)).r;
    retrievedMasks[2] = bitmap.read(ushort2(coords.x - offset.x, coords.y - offset.y)).r;
    retrievedMasks[3] = bitmap.read(ushort2(coords.x + offset.y, coords.y - offset.x)).r;
    
    return any(retrievedMasks == isInsideMask);
}

kernel void createTextSignedDistanceField(device   float2  *baseSearchParameters      [[ buffer(0) ]],
                                          constant ushort3 *upperSearchParameters     [[ buffer(1) ]],

                                          constant ushort  *upperLevelOffsets         [[ buffer(2) ]],
                                          constant ushort  *levelSizes                [[ buffer(3) ]],
                                          constant float2  &maxDistanceAndHalfInverse [[ buffer(4) ]],

                                          texture2d<ushort, access::read>  bitmap              [[ texture(0) ]],
                                          texture2d<ushort, access::read>  mipmapLevels        [[ texture(1) ]],
                                          texture2d<float,  access::write> signedDistanceField [[ texture(2) ]],

                                          ushort2 id [[ thread_position_in_grid ]])
{
    bool isInside = readCompressedBitmap(bitmap, id);
    ushort searchStartOffset = 0;
    
    // If the thread's pixel is inside, the mask of `2` searches for neighboring outside pixels
    // If the thread's pixel is outside, the mask of `1` searches for neighboring inside pixels
    ushort isInsideMask = select(1, 2, isInside);
    
    for (ushort levelID = mipmapLevels.get_num_mip_levels(); levelID > 0; --levelID)
    {
        ushort2 coords = id >> levelID;
        ushort levelID_minus1 = levelID - 1;
        
        ushort searchStart = upperLevelOffsets[levelID_minus1];
        ushort searchEnd   = searchStart + levelSizes[levelID];
        ushort searchIndex = searchStart + searchStartOffset;
        
        do
        {
            ushort3 retrievedParameters = upperSearchParameters[searchIndex];

            if (sampleMipmapLevel(mipmapLevels, levelID_minus1,
                                  coords, retrievedParameters.xy, isInsideMask))
            {
                searchStartOffset = retrievedParameters[2];
                break;
            }

            ++searchIndex;
        }
        while (searchIndex < searchEnd);

        if (searchIndex == searchEnd)
        {
            searchStartOffset = 65535;
            break;
        }
    }

    float closestDistance = maxDistanceAndHalfInverse[0];
    half distanceSign = select(-1, 1, isInside);
    isInsideMask = select(255, 0, isInside);

    if (searchStartOffset < 65535)
    {
        ushort searchIndex = searchStartOffset;
        ushort searchEnd   = levelSizes[0];

        do {
            float2 retrievedParameters = baseSearchParameters[searchIndex];

            if (sampleCompressedBitmap(bitmap, id, as_type<ushort2>(retrievedParameters[0]), isInsideMask))
            {
                closestDistance = retrievedParameters[1];
                break;
            }

            ++searchIndex;
        }
        while (searchIndex < searchEnd);
    }

    float output = fma(copysign(closestDistance, float(distanceSign)), maxDistanceAndHalfInverse[1], 0.5);
    signedDistanceField.write(float4{ output }, id);
}
#endif

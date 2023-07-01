//
//  SceneColorUpdate.metal.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if __METAL_IOS__
#include <metal_stdlib>
#include "../../Other/Metal Utilities/ColorUtilities.h"
using namespace metal;

kernel void checkSegmentationTexture(texture2d<uint, access::write>  triangleIDTexture   [[ texture(0) ]],
                                     texture2d<half, access::sample> segmentationTexture [[ texture(1) ]],
                                     
                                     ushort2 id [[ thread_position_in_grid ]])
{
    if (segmentationTexture.read(id).r == 0)
    {
        constexpr sampler segmentationSampler(coord::pixel, filter::nearest);
        
        constexpr ushort2 offsets[4] = {
            {     2, 1 },
            {     0, 2 },
            { 65535, 0 },
            { 1, 65535 }
        };
        
        bool4 comparisons;
        
        for (uchar i = 0; i < 4; ++i)
        {
            float2 adjustedCoords = float2(id + offsets[i]);
            half4 result = segmentationTexture.gather(segmentationSampler, adjustedCoords);
            
            comparisons[i] = all(result == 0);
        }
        
        if (all(comparisons))
        {
            return;
        }
    }
    
    ushort2 texCoords = id << 2;
    
#define OVERWRITE_ID_TEXTURE_BLOCK(i, j)                            \
triangleIDTexture.write(__UINT32_MAX__, texCoords + ushort2(i, j)); \

#define OVERWRITE_ID_TEXTURE_BLOCK_4(j)                             \
OVERWRITE_ID_TEXTURE_BLOCK(0, j);                                   \
OVERWRITE_ID_TEXTURE_BLOCK(1, j);                                   \
OVERWRITE_ID_TEXTURE_BLOCK(2, j);                                   \
OVERWRITE_ID_TEXTURE_BLOCK(3, j);                                   \
    
    OVERWRITE_ID_TEXTURE_BLOCK_4(0);
    OVERWRITE_ID_TEXTURE_BLOCK_4(1);
    OVERWRITE_ID_TEXTURE_BLOCK_4(2);
    OVERWRITE_ID_TEXTURE_BLOCK_4(3);
}

kernel void resampleColorTextures(texture2d<half, access::sample> colorTextureY_in     [[ texture(0) ]],
                                  texture2d<half, access::sample> colorTextureCbCr_in  [[ texture(1) ]],
                                  
                                  texture2d<half, access::write>  colorTextureY_out    [[ texture(2) ]],
                                  texture2d<half, access::write>  colorTextureCbCr_out [[ texture(3) ]],
                                  
                                  ushort2 id [[ thread_position_in_grid ]])
{
    constexpr sampler textureSampler(filter::linear);
    float2 chromaCoords = fma(float2(id), float2(1.0 / 768, 1.0 / 576), float2(0.5 / 768, 0.5 / 576));
    
    half2 sampleChroma = colorTextureCbCr_in.sample(textureSampler, chromaCoords).rg;
    colorTextureCbCr_out.write(half4{ sampleChroma.r, sampleChroma.g }, id);
    
    half4 sampleLuma;
    float2 lumaCoords = chromaCoords + float2(-0.5 / 1536, -0.5 / 1152);
    sampleLuma[0] = colorTextureY_in.sample(textureSampler, lumaCoords).r;
    
    float newLumaCoordX = lumaCoords.x + 1.0 / 1536;
    sampleLuma[1] = colorTextureY_in.sample(textureSampler, float2(newLumaCoordX, lumaCoords.y)).r;
    
    lumaCoords.y += 1.0 / 1152;
    sampleLuma[2] = colorTextureY_in.sample(textureSampler, float2(newLumaCoordX, lumaCoords.y)).r;
    
    sampleLuma[3] = colorTextureY_in.sample(textureSampler, lumaCoords).r;
    
    ushort2 id_times_2 = id << 1;
    colorTextureY_out.write(half4{ sampleLuma[0] }, id_times_2);
    colorTextureY_out.write(half4{ sampleLuma[1] }, id_times_2 | ushort2(1, 0));
    colorTextureY_out.write(half4{ sampleLuma[2] }, id_times_2 | ushort2(1, 1));
    colorTextureY_out.write(half4{ sampleLuma[3] }, id_times_2 | ushort2(0, 1));
    
    sampleLuma.xy += sampleLuma.zw;
    half averageLuma = (sampleLuma.x + sampleLuma.y) * 0.25;
    colorTextureY_out.write(half4{ averageLuma }, id, 1);
}



inline uint compressColor(half3 in)
{
    uchar3 color = uchar3(rint(in * 255));
    return as_type<uint>(uchar4(color.bgr, 0));
}

inline void innerLoopComparison(thread ushort &offsetY, thread bool &shouldContinue,
                                thread ushort &previousExpandedColumnOffset, ushort nextExpandedColumnOffset,
                                thread float2 &p_chroma, float2 p_delta_vertical,
                                thread float  &w_chroma, float  w_delta_vertical)
{
    ++previousExpandedColumnOffset;
    
    if (previousExpandedColumnOffset >= nextExpandedColumnOffset)
    {
        shouldContinue = false;
        return;
    }
    
    ++offsetY;
    
    p_chroma += p_delta_vertical;
    w_chroma += w_delta_vertical;
}
 
kernel void executeColorUpdate(device   float4  *vertices                [[ buffer(0) ]],
                               device   uint    *vertexOffsets           [[ buffer(1) ]],
                               device   uint3   *reducedIndices          [[ buffer(2) ]],
                               device   uint    *triangleIDs             [[ buffer(3) ]],
                               
                               device   uint4   *reducedColors           [[ buffer(4) ]],
                               device   float4  *rasterizationComponents [[ buffer(5) ]],
                               device   ushort2 *textureOffsets          [[ buffer(6) ]],
                               
                               device   uchar   *columnCounts            [[ buffer(7) ]],
                               device   ushort  *columnOffsets           [[ buffer(8) ]],
                               constant uint    *columnOffsets256        [[ buffer(9) ]],
                               device   uchar   *expandedColumnOffsets   [[ buffer(10) ]],
                               
                               device   uchar2  *smallTriangleLumaRows   [[ buffer(11) ]],
                               device   uchar2  *largeTriangleLumaRows   [[ buffer(12) ]],
                               device   uchar2  *smallTriangleChromaRows [[ buffer(13) ]],
                               device   uchar2  *largeTriangleChromaRows [[ buffer(14) ]],
                               
                               texture2d<uint, access::sample> triangleIDTexture [[ texture(0) ]],
                               texture2d<half, access::sample> colorTextureY     [[ texture(1) ]],
                               texture2d<half, access::sample> colorTextureCbCr  [[ texture(2) ]],
                               
                               uint id [[ thread_position_in_grid ]])
{
    uint  triangleID = triangleIDs[id];
    uint3 indices    = reducedIndices[triangleID];
    
    float4 rawPositions[3] = {
        vertices[vertexOffsets[indices[0]]],
        vertices[vertexOffsets[indices[1]]],
        vertices[vertexOffsets[indices[2]]]
    };
    
    // Determine whether the triangle faces forward
    
    float BwCw   = rawPositions[1].w * rawPositions[2].w;
    float AxBwCw = rawPositions[0].x * BwCw;
    float AyBwCw = rawPositions[0].y * BwCw;
    
    float AwBw = rawPositions[0].w * rawPositions[1].w;
    float AwCw = rawPositions[0].w * rawPositions[2].w;
    
    float ACx_expanded = fma(AwBw, rawPositions[2].x, -AxBwCw);
    float ABy_expanded = fma(AwCw, rawPositions[1].y, -AyBwCw);
    float ACxABy_expanded = ACx_expanded * ABy_expanded;
    
    float ABx_expanded = fma(AwCw, rawPositions[1].x, -AxBwCw);
    float ACy_expanded = fma(AwBw, rawPositions[2].y, -AyBwCw);
    
    float cross_product = fma(ABx_expanded, ACy_expanded, -ACxABy_expanded);
    if (cross_product <= 0) { return; }
    
    // Update low-resolution color
    
    float4 occlusionTestPosition = rawPositions[0] + rawPositions[1] + rawPositions[2];
    
#define FIRST_OCCLUSION_TEST_BLOCK(occlusionClip, component)                    \
float2 texCoords    = fma(occlusionClip, float2(512, -384), float2(512, 384));  \
uint   comparisonID = triangleIDTexture.read(ushort2(texCoords)).r;             \
                                                                                \
if (comparisonID == triangleID)                                                 \
{                                                                               \
    constexpr sampler textureSampler(filter::linear);                           \
    texCoords *= float2(1.0 / 1024, 1.0 / 768);                                 \
                                                                                \
    half3 color;                                                                \
    color.r  = colorTextureY   .sample(textureSampler, texCoords).r;            \
    color.gb = colorTextureCbCr.sample(textureSampler, texCoords).rg;           \
                                                                                \
    reducedColors[triangleID][component] = compressColor(color);                \
}                                                                               \
    
    if (all(occlusionTestPosition.xyz <  occlusionTestPosition.w) &&
        all(occlusionTestPosition.xy  > -occlusionTestPosition.w) &&
        occlusionTestPosition.z > 0)
    {
        float multiplier = fast::divide(1, occlusionTestPosition.w);
        FIRST_OCCLUSION_TEST_BLOCK(occlusionTestPosition.xy * multiplier, 0)
    }
    
    ushort winding = as_type<uchar4>(rasterizationComponents[triangleID].w).x;
    
    for (ushort i = 1; i < 4; ++i)
    {
        ushort index = winding + i;
        index -= select(1, 4, index >= 4);
        
        float4 testPosition = fma(rawPositions[index], 3, occlusionTestPosition);
        
        if (all(testPosition.xyz <  testPosition.w) &&
            all(testPosition.xy  > -testPosition.w) &&
            testPosition.z > 0)
        {
            testPosition.w = fast::divide(1, testPosition.w);
            testPosition.xy *= testPosition.w;
            
            FIRST_OCCLUSION_TEST_BLOCK(testPosition.xy, i);
        }
    }
    
    // Update high-resolution color
    
    float3 A, B, C;
    
    if (winding == 0)
    {
        A = rawPositions[0].xyw;
        B = rawPositions[1].xyw;
        C = rawPositions[2].xyw;
    }
    else if (winding == 1)
    {
        A = rawPositions[1].xyw;
        B = rawPositions[2].xyw;
        C = rawPositions[0].xyw;
    }
    else
    {
        A = rawPositions[2].xyw;
        B = rawPositions[0].xyw;
        C = rawPositions[1].xyw;
    }
    
    float2 p_delta_horizontal = B.xy - A.xy;
    float  w_delta_horizontal = B.z  - A.z;
    
    float3 components = rasterizationComponents[triangleID].xyz;
    if (components.z <= 0) { return; }
    
    float longestSideLength_reciprocal_half   = fast::divide(0.5, components.x);
    float orthogonalComponent_reciprocal_half = fast::divide(0.5, components.z);
    
    float longestSideLength_reciprocal = longestSideLength_reciprocal_half + longestSideLength_reciprocal_half;
    float interpolationParameter = components.y * longestSideLength_reciprocal;
    
    float2 interpolatedXY = fma(p_delta_horizontal, interpolationParameter, A.xy);
    float2 p_delta_vertical = C.xy - interpolatedXY;
    
    float interpolatedW = fma(w_delta_horizontal, interpolationParameter, A.z);
    float w_delta_vertical = C.z - interpolatedW;
    
    // Transform coordinates
    
    A.xy = A.xy * float2(0.5, -0.5);
    
    p_delta_horizontal *= float2(longestSideLength_reciprocal_half, -longestSideLength_reciprocal_half);
    p_delta_vertical *= float2(orthogonalComponent_reciprocal_half, -orthogonalComponent_reciprocal_half);
    
    w_delta_horizontal *= longestSideLength_reciprocal;
    w_delta_vertical *= (orthogonalComponent_reciprocal_half + orthogonalComponent_reciprocal_half);
    
    // Prepare for loop
    
    float2 p_outer_loop = fma(p_delta_vertical, 0.5, A.xy);
    p_outer_loop = fma(p_delta_horizontal, 0.5, p_outer_loop);
    
    float w_outer_loop = fma(w_delta_vertical, 0.5, A.z);
    w_outer_loop = fma(w_delta_horizontal, 0.5, w_outer_loop);
    
    uint columnOffset = columnOffsets256[triangleID >> 8] + columnOffsets[triangleID];
    uint columnEnd    = columnOffset + columnCounts[triangleID];
    
    device uchar2 *lumaRows;
    device uchar2 *chromaRows;
    
    ushort2 textureStart = textureOffsets[triangleID];
    
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
    
    ushort previousExpandedColumnOffset = 0;
    ushort nextExpandedColumnOffset = expandedColumnOffsets[columnOffset];
    
    ushort lastHeight = 0;
    ushort currentHeight = nextExpandedColumnOffset;
    
    // Loop by column
    
    while (true)
    {
        ushort futureExpandedColumnOffset;
        uint columnOffset_plus_1 = columnOffset + 1;
        
        if (columnOffset_plus_1 < columnEnd) { futureExpandedColumnOffset = expandedColumnOffsets[columnOffset_plus_1]; }
        else                                 { futureExpandedColumnOffset = nextExpandedColumnOffset; }
        
        ushort nextHeight = futureExpandedColumnOffset - nextExpandedColumnOffset;
        ushort offsetY = 0;
        
        float2 p_chroma = p_outer_loop;
        float  w_chroma = w_outer_loop;
        
        // Loop by texel
        
        for (bool shouldContinue = true; shouldContinue;
             innerLoopComparison(offsetY, shouldContinue,
                                 previousExpandedColumnOffset, nextExpandedColumnOffset,
                                 p_chroma, p_delta_vertical,
                                 w_chroma, w_delta_vertical))
        {
            float w_chroma_half = w_chroma * 0.49;
            if (w_chroma_half <= 0 || any(abs(p_chroma) > abs(w_chroma_half))) { continue; }
            
            float w_chroma_recip = fast::divide(1.0, w_chroma);
            
            float2 center_oriented_position = p_chroma * w_chroma_recip;
            float2 adjusted_position = center_oriented_position + 0.5;
            
            constexpr sampler idSampler(filter::nearest);
            uint comparisonID = triangleIDTexture.sample(idSampler, float2(adjusted_position.x, adjusted_position.y)).r;
            
            if (comparisonID != triangleID)
            {
                if (comparisonID == __UINT32_MAX__) { continue; }
                
                uint3 candidateIndices = reducedIndices[comparisonID];
                
                if (all(candidateIndices != indices.x) &&
                    all(candidateIndices != indices.y) &&
                    all(candidateIndices != indices.z))
                {
                    continue;
                }
            }
            
            w_chroma_recip *= 0.25;
            
            half2 dPdx_half = half2(fma(center_oriented_position, -w_delta_horizontal, p_delta_horizontal)) * w_chroma_recip;
            half2 dPdy_half = half2(fma(center_oriented_position, -w_delta_vertical,   p_delta_vertical))   * w_chroma_recip;
#define HALF_GRADIENT gradient2d(float2(dPdx_half), float2(dPdy_half))
            
            half2 dPdx_full = dPdx_half + dPdx_half;
            half2 dPdy_full = dPdy_half + dPdy_half;
#define FULL_GRADIENT gradient2d(float2(dPdx_full), float2(dPdy_full))
            
            constexpr sampler colorSampler(filter::linear, mip_filter::linear, max_anisotropy(16));
            
            half2 sampleChroma = colorTextureCbCr.sample(colorSampler, adjusted_position, FULL_GRADIENT).rg;
            half4 sampleLuma;
            
            adjusted_position -= float2(dPdx_half + dPdy_half);
            sampleLuma.x = colorTextureY.sample(colorSampler, adjusted_position, HALF_GRADIENT).r;
            
            adjusted_position += float2(dPdx_full);
            sampleLuma.y = colorTextureY.sample(colorSampler, adjusted_position, HALF_GRADIENT).r;
            
            adjusted_position += float2(dPdy_full);
            sampleLuma.w = colorTextureY.sample(colorSampler, adjusted_position, HALF_GRADIENT).r;
            
            adjusted_position -= float2(dPdx_full);
            sampleLuma.z = colorTextureY.sample(colorSampler, adjusted_position, HALF_GRADIENT).r;
            
            
            
            using namespace SceneColorReconstruction;
            
            Texel sampleTexel;
            
            sampleTexel.packLuma(sampleLuma);
            sampleTexel.packChroma(sampleChroma);
            
            ushort2 texCoords(textureStart.x, textureStart.y + offsetY);
            ushort  nextOffsetY;
            
            texture.write(sampleTexel, texCoords);
            texture.createPadding(sampleTexel, texCoords,
                                  lastHeight, currentHeight, nextHeight,
                                  offsetY, nextOffsetY);
        }
        
        ++columnOffset;
        
        if (columnOffset >= columnEnd)
        {
            return;
        }
        
        ++textureStart.x;
        nextExpandedColumnOffset = futureExpandedColumnOffset;
        
        lastHeight = currentHeight;
        currentHeight = nextHeight;
        
        p_outer_loop += p_delta_horizontal;
        w_outer_loop += w_delta_horizontal;
    }
}

// Create a serialization format exporting two buffers. The first buffer
// contains tiles of 6x6 luma/12x12 chroma pixels; the second contains an array
// of 14x14 luma/28x28 chroma pixels. These are then concatenated into one
// massive buffer, with a header stating where each zone starts. This is a
// lossless format, but requires the user to manually convert YCbCr -> RGB
// afterward. It should ZIP compress quite nicely.
//
// This shader not only works for an initial demo, it should be production-ready
// and usable in a final product. It runs very fast and exports data in a very
// compact format.

struct __attribute__((aligned(64))) tile_12x12 {
  float4 vertexPositions[3]; // 48 bytes; W component unused
  float2 textureCoordinates[3]; // 24 bytes; UV indices within the tile
  // 24 bytes padding
  // 320 bytes total
  uchar2 luma[6 * 6]; // 72 bytes
  uchar chroma[12 * 12]; // 144 bytes
  // 8 bytes of padding
  
};

struct __attribute__((aligned(64))) tile_28x28 {
  float4 vertexPositions[3]; // 48 bytes; W component unused
  float2 textureCoordinates[3]; // 24 bytes; UV indices within the tile
  // 24 bytes padding
  // 1280 bytes total
  uchar2 luma[14 * 14]; // 392 bytes
  uchar chroma[28 * 28]; // 784 bytes
  // 8 bytes of padding
};

// Getting the memory copying from texture -> tile performant is critical to
// this shader. It is not that difficult, but requires expertise with Metal.
// Everything else is quite straightforward.
kernel void executeColorExport(device   float4  *vertices                [[ buffer(0) ]],
                               device   uint    *vertexOffsets           [[ buffer(1) ]],
                               device   uint3   *reducedIndices          [[ buffer(2) ]],
                               
                               device   uint4   *reducedColors           [[ buffer(4) ]],
                               device   float4  *rasterizationComponents [[ buffer(5) ]],
                               device   ushort2 *textureOffsets          [[ buffer(6) ]],
                               
                               device   uchar   *columnCounts            [[ buffer(7) ]],
                               device   ushort  *columnOffsets           [[ buffer(8) ]],
                               constant uint    *columnOffsets256        [[ buffer(9) ]],
                               device   uchar   *expandedColumnOffsets   [[ buffer(10) ]],
                               
                               device   uchar2  *smallTriangleLumaRows   [[ buffer(11) ]],
                               device   uchar2  *largeTriangleLumaRows   [[ buffer(12) ]],
                               device   uchar2  *smallTriangleChromaRows [[ buffer(13) ]],
                               device   uchar2  *largeTriangleChromaRows [[ buffer(14) ]],
                               
                               device   void    *serializedBlocks        [[ buffer(15) ]],
                               constant uint    &numSmallTriangles       [[ buffer(16) ]],
                               
                               uint triangleID [[ thread_position_in_grid ]])
{
  uint3 indices    = reducedIndices[triangleID];
  
  float4 rawPositions[3] = {
    vertices[vertexOffsets[indices[0]]],
    vertices[vertexOffsets[indices[1]]],
    vertices[vertexOffsets[indices[2]]]
  };
  
  ushort winding = as_type<uchar4>(rasterizationComponents[triangleID].w).x;
  
  float4 vertexPositions[3];
  if (winding == 0)
  {
    vertexPositions[0].xyz = rawPositions[0].xyz;
    vertexPositions[1].xyz = rawPositions[1].xyz;
    vertexPositions[2].xyz = rawPositions[2].xyz;
  }
  else if (winding == 1)
  {
    vertexPositions[0].xyz = rawPositions[1].xyz;
    vertexPositions[1].xyz = rawPositions[2].xyz;
    vertexPositions[2].xyz = rawPositions[0].xyz;
  }
  else
  {
    vertexPositions[0].xyz = rawPositions[2].xyz;
    vertexPositions[1].xyz = rawPositions[0].xyz;
    vertexPositions[2].xyz = rawPositions[1].xyz;
  }
  vertexPositions[0].w = 0;
  vertexPositions[1].w = 0;
  vertexPositions[2].w = 0;
  
  float3 components = rasterizationComponents[triangleID].xyz;
  float longestSideLength   = components.x;
  float parallelComponent   = components.y;
  float orthogonalComponent = components.z;
  
  float2 texCoords[3];
  texCoords[0] = float2(0, 0);
  texCoords[1] = float2(longestSideLength, 0);
  texCoords[2] = float2(parallelComponent, orthogonalComponent);
  
  ushort2 textureStart = textureOffsets[triangleID];
  
  bool isLarge = textureStart.y & 0x8000;
  uint indexInZone;
  ulong absoluteOffsetInBytes;
  
  if (isLarge) {
    textureStart.y &= 0x7FFF;
    constexpr ushort TILES_PER_ROW = 16384 / 32; // by chroma
    ushort2 tileIndexInTexture = textureStart / 16; // by luma
    indexInZone = uint(tileIndexInTexture.y * TILES_PER_ROW) + tileIndexInTexture.x;
    absoluteOffsetInBytes = ulong(320 * indexInZone);
  } else {
    constexpr ushort TILES_PER_ROW = 16384 / 16; // by chroma
    ushort2 tileIndexInTexture = textureStart / 8; // by luma
    indexInZone = uint(tileIndexInTexture.y * TILES_PER_ROW) + tileIndexInTexture.x;
    absoluteOffsetInBytes = ulong(320 * numSmallTriangles) + ulong(1280 * indexInZone);
  }
  
  auto baseAddress = ((device uchar*)serializedBlocks) + absoluteOffsetInBytes;
#pragma clang loop unroll(full)
  for (int i = 0; i < 3; ++i) {
    auto vertexPositionsAddress = (device float4*)baseAddress;
    vertexPositionsAddress[i] = vertexPositions[i];
  }
  baseAddress += 48;
#pragma clang loop unroll(full)
  for (int i = 0; i < 3; ++i) {
    auto textureCoordinatesAddress = (device float2*)baseAddress;
    textureCoordinatesAddress[i] = texCoords[i];
  }
  baseAddress += 24;
  baseAddress += 8; // padding
  
  device uchar2 *lumaRows;
  device uchar2 *chromaRows;
  if (isLarge)
  {
    lumaRows   = largeTriangleLumaRows;
    chromaRows = largeTriangleChromaRows;
  }
  else
  {
    lumaRows   = smallTriangleLumaRows;
    chromaRows = smallTriangleChromaRows;
  }
  
  // TODO: Fetch the correct pointers to read from
  device uchar2 *chromaAddress = nullptr;
  device uchar *lumaAddress = nullptr;
  ushort numCols = (isLarge ? 14 : 6);
  
  for (ushort i = 0; i < numCols; ++i) {
    // TODO: Fetch an entire row from the source texture at once, including the padding.
    
    if (isLarge) {
#pragma clang loop unroll(full)
      for (ushort j = 0; j < 14; ++j) {
        // Do something
      }
    } else {
#pragma clang loop unroll(full)
      for (ushort j = 0; j < 6; ++j) {
        // Do something
      }
    }
    
    // TODO: Store the row directly to output.
    // Small triangles: 12 bytes for either plane
    // Large triangles: 28 bytes for either plane
    // The only difference is in the number of columns.
    chromaAddress += 8192;
    lumaAddress += 16384;
  }
}

#endif

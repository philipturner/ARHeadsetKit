//
//  LensDistortionCorrection.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#include <metal_stdlib>
using namespace metal;

typedef struct {
    ushort2 leftViewportOrigin;
    ushort  rightViewportOriginX;
    ushort  framebufferMiddle;
    
    ushort  viewportEndY_minus1;
    ushort  leftViewportEndX;
    ushort  rightViewportEndX;
    ushort  optionalLastDispatchY;
    
    half    clipOffset;
    float   maxRadiusSquared;
    float   maxRadiusSquaredInverse;
    
    half    k1_red;
    half    k1_green;
    half    k1_blue;
    
    half    k2_red;
    half    k2_green;
    half    k2_blue;
    
    half    compressionRatio;
    float   intermediateSideLengthHalf;
    bool    clearingFramebuffer;
    
    bool2   showingRedBlueColor;
} LensDistortionUniforms;

kernel void clearFramebuffer(constant LensDistortionUniforms &uniforms [[ buffer(0) ]],
                             
                             texture2d<half, access::write> framebuffer [[ texture(1) ]],
                             
                             ushort2 id [[ thread_position_in_grid ]])
{
    ushort2 mappedID = id << 1;
    
    if (mappedID.y >= uniforms.leftViewportOrigin.y && mappedID.y < uniforms.viewportEndY_minus1)
    {
        if (mappedID.x >= uniforms.rightViewportOriginX)
        {
            if (mappedID.x < uniforms.rightViewportEndX) { return; }
        }
        else if (mappedID.x >= uniforms.leftViewportOrigin.x)
        {
            if (mappedID.x < uniforms.leftViewportEndX) { return; }
        }
    }
    
    framebuffer.write(half4{ 0, 0, 0 }, mappedID);
    
    mappedID.x += 1;
    framebuffer.write(half4{ 0, 0, 0 }, mappedID);
    
    if (id.y == uniforms.optionalLastDispatchY)
    {
        return;
    }
    
    mappedID.y += 1;
    framebuffer.write(half4{ 0, 0, 0 }, mappedID);
    
    mappedID.x -= 1;
    framebuffer.write(half4{ 0, 0, 0 }, mappedID);
}



constant ushort  intermediateSideLength [[ function_constant(0) ]];
constant ushort2 vrrTextureDimensions   [[ function_constant(1) ]];

constant bool    checkingMiddleX        [[ function_constant(2) ]];
constant bool    checkingMiddleY        [[ function_constant(3) ]];

constant ushort4 x_origins_0            [[ function_constant(10) ]];
constant ushort4 x_origins_1            [[ function_constant(11) ]];
constant ushort4 x_origins_2            [[ function_constant(12) ]];
constant ushort4 x_origins_3            [[ function_constant(13) ]];

constant ushort4 x_checkpoints_0        [[ function_constant(14) ]];
constant ushort4 x_checkpoints_1        [[ function_constant(15) ]];
constant ushort4 x_checkpoints_2        [[ function_constant(16) ]];
constant ushort4 x_checkpoints_3        [[ function_constant(17) ]];

constant ushort4 y_origins_0            [[ function_constant(20) ]];
constant ushort4 y_origins_1            [[ function_constant(21) ]];
constant ushort4 y_origins_2            [[ function_constant(22) ]];
constant ushort4 y_origins_3            [[ function_constant(23) ]];

constant ushort4 y_checkpoints_0        [[ function_constant(24) ]];
constant ushort4 y_checkpoints_1        [[ function_constant(25) ]];
constant ushort4 y_checkpoints_2        [[ function_constant(26) ]];
constant ushort4 y_checkpoints_3        [[ function_constant(27) ]];



#define MAKE_VRR_ARRAY(input0, input1)                      \
input0[0], input0[1], input0[2], input0[3],                 \
input1[0], input1[1], input1[2], input1[3]                  \

#define MAKE_UPPER_ORIGINS(input0, input1, index)           \
MAKE_VRR_ARRAY(input0, input1), vrrTextureDimensions[index] \

#define MAKE_UPPER_CHECKPOINTS(input0, input1)              \
MAKE_VRR_ARRAY(input0, input1), intermediateSideLength      \

constant ushort x_lower_origins[9] = { 0, MAKE_VRR_ARRAY(x_origins_0, x_origins_1) };
constant ushort y_lower_origins[9] = { 0, MAKE_VRR_ARRAY(y_origins_0, y_origins_1) };

constant ushort x_upper_origins[9] = { MAKE_UPPER_ORIGINS(x_origins_2, x_origins_3, 0) };
constant ushort y_upper_origins[9] = { MAKE_UPPER_ORIGINS(y_origins_2, y_origins_3, 1) };

constant ushort x_lower_checkpoints[9] = { 0, MAKE_VRR_ARRAY(x_checkpoints_0, x_checkpoints_1) };
constant ushort y_lower_checkpoints[9] = { 0, MAKE_VRR_ARRAY(y_checkpoints_0, y_checkpoints_1) };

constant ushort x_upper_checkpoints[9] = { MAKE_UPPER_CHECKPOINTS(x_checkpoints_2, x_checkpoints_3) };
constant ushort y_upper_checkpoints[9] = { MAKE_UPPER_CHECKPOINTS(y_checkpoints_2, y_checkpoints_3) };

constant float2 shifts(
    x_lower_origins[8] - x_lower_checkpoints[8],
    y_lower_origins[8] - y_lower_checkpoints[8]
);

constant float x_lower_end = shifts[0] + x_lower_checkpoints[8];
constant float y_lower_end = shifts[1] + y_lower_checkpoints[8];

constant float x_upper_start = shifts[0] + x_upper_checkpoints[0];
constant float y_upper_start = shifts[1] + y_upper_checkpoints[0];

constant float2 vrrTransformOffset = intermediateSideLength * 0.5 + float2(shifts);



#define get_m(start, end, o, c)                             \
(float(o[end]) - o[start]) /                                \
(float(c[end]) - c[start])                                  \

#define get_b(start, end, o, c)                             \
o[start] - get_m(start, end, o, c) * (shift + c[start])     \

#define set_block(start, mid, end, f1, f2, f3)              \
if      (f1[mid] == 0) { f2(start, end) }                   \
else if (f3(mid))      { f2(start, mid) }                   \
else                   { f2(  mid, end) }                   \

#define set_group(start, mid, end, f1, f2, f3)              \
if (f1[mid] == 0)                                           \
{                                                           \
    f2(start, end)                                          \
}                                                           \
else if (f3(mid))                                           \
{                                                           \
    set_block(start, (start + mid) / 2, mid, f1, f2, f3)    \
}                                                           \
else                                                        \
{                                                           \
    set_block(mid, (mid + end) / 2, end, f1, f2, f3)        \
}                                                           \

#define set_generic(start, end, element, o, c)              \
coords[element] = fma(coords[element],                      \
                      get_m(start, end, o, c),              \
                      get_b(start, end, o, c));             \

#define compare_generic(element, c, index)                  \
coords[element] < shift + c[index]                          \

#define correct_generic(element, f1, f2, f3, f4)            \
const auto shift = shifts[element];                         \
                                                            \
if (f1[4] == 0) { f2(0, 8)    }                             \
else if (f3(4)) { f4(0, 2, 4) }                             \
else            { f4(4, 6, 8) }                             \

inline void correctX(thread float2 &coords)
{
    if (x_lower_origins[8] != 0 && coords.x < x_lower_end)
    {
#define xlo x_lower_origins
#define xlc x_lower_checkpoints
        
#define set_xl(start, end) set_generic(start, end, 0, xlo, xlc)
#define compare_xl(index)  compare_generic(0, xlc, index)
    
#define set_xl_group(start, mid, end)               \
set_group(start, mid, end, xlc, set_xl, compare_xl) \

        correct_generic(0, xlc, set_xl, compare_xl, set_xl_group)
    }
    else if (x_upper_origins[8] != 0 && coords.x > x_upper_start)
    {
#define xuo x_upper_origins
#define xuc x_upper_checkpoints
        
#define set_xu(start, end) set_generic(start, end, 0, xuo, xuc)
#define compare_xu(index)  compare_generic(0, xuc, index)
    
#define set_xu_group(start, mid, end)               \
set_group(start, mid, end, xuc, set_xu, compare_xu) \
        
        correct_generic(0, xuc, set_xu, compare_xu, set_xu_group)
    }
}

inline void correctY(thread float2 &coords)
{
    if (y_lower_origins[8] != 0 && coords.y < y_lower_end)
    {
#define ylo y_lower_origins
#define ylc y_lower_checkpoints
        
#define set_yl(start, end) set_generic(start, end, 1, ylo, ylc)
#define compare_yl(index)  compare_generic(1, ylc, index)
    
#define set_yl_group(start, mid, end)               \
set_group(start, mid, end, ylc, set_yl, compare_yl) \

        correct_generic(1, ylc, set_yl, compare_yl, set_yl_group)
    }
    else if (y_upper_origins[8] != 0 && coords.y > y_upper_start)
    {
#define yuo y_upper_origins
#define yuc y_upper_checkpoints
        
#define set_yu(start, end) set_generic(start, end, 1, yuo, yuc)
#define compare_yu(index)  compare_generic(1, yuc, index)
    
#define set_yu_group(start, mid, end)               \
set_group(start, mid, end, yuc, set_yu, compare_yu) \
        
        correct_generic(1, yuc, set_yu, compare_yu, set_yu_group)
    }
}



inline half3 createInverseDistortionMultipliers(thread float &radius_squared, constant LensDistortionUniforms &uniforms)
{
    // Correct lens distortion and chromatic aberration
    
    radius_squared *= uniforms.maxRadiusSquaredInverse;
    half radius_to_fourth = half(radius_squared) * half(radius_squared);
    
    half3 output = {
        fma(half(radius_squared), uniforms.k1_red,   uniforms.compressionRatio),
        fma(half(radius_squared), uniforms.k1_green, uniforms.compressionRatio),
        fma(half(radius_squared), uniforms.k1_blue,  uniforms.compressionRatio)
    };
    
    return {
        fma(radius_to_fourth, uniforms.k2_red,   output[0]),
        fma(radius_to_fourth, uniforms.k2_green, output[1]),
        fma(radius_to_fourth, uniforms.k2_blue,  output[2]),
    };
}

inline void sampleColor(float2 coords_red, float2 coords_green, float2 coords_blue,
                        thread half4 &leftColor, thread half4 &rightColor, texture2d_array<half, access::sample> input)
{
    constexpr sampler colorSampler(coord::pixel, filter::linear, address::clamp_to_edge);

    leftColor = {
        input.sample(colorSampler, coords_red,   0).r,
        input.sample(colorSampler, coords_green, 0).g,
        input.sample(colorSampler, coords_blue,  0).b,
    };

    rightColor = {
        input.sample(colorSampler, coords_red,   1).r,
        input.sample(colorSampler, coords_green, 1).g,
        input.sample(colorSampler, coords_blue,  1).b,
    };
}

inline void writeColor(ushort2 id, constant LensDistortionUniforms &uniforms,
                       thread half4 &leftColor, thread half4 &rightColor, texture2d<half, access::write> output)
{
    leftColor.rb  = select(0, leftColor.rb,  uniforms.showingRedBlueColor);
    rightColor.rb = select(0, rightColor.rb, uniforms.showingRedBlueColor);
    
    ushort2 writeDestination = id + uniforms.leftViewportOrigin;
    if (writeDestination.x < uniforms.framebufferMiddle) { output.write(leftColor,  writeDestination); }
    
    writeDestination.x = id.x + uniforms.rightViewportOriginX;
    if (writeDestination.x >= uniforms.framebufferMiddle) { output.write(rightColor, writeDestination); }
}



kernel void optimizedCorrectLensDistortion(constant LensDistortionUniforms &uniforms [[ buffer(0) ]],
                                           
                                           texture2d_array<half, access::sample> input  [[ texture(0) ]],
                                           texture2d      <half, access::write>  output [[ texture(1) ]],
                                           
                                           ushort2 id [[ thread_position_in_grid ]])
{
    float2 clipCoords = float2(half2(id) + uniforms.clipOffset);
    float radius_squared = length_squared(clipCoords);
    
    half4 leftColor, rightColor;
    
    if (radius_squared <= uniforms.maxRadiusSquared)
    {
        half3 inverseDistortionMultipliers = createInverseDistortionMultipliers(radius_squared, uniforms);
        
        float2 coords_red   = fma(clipCoords, inverseDistortionMultipliers[0], vrrTransformOffset);
        float2 coords_green = fma(clipCoords, inverseDistortionMultipliers[1], vrrTransformOffset);
        float2 coords_blue  = fma(clipCoords, inverseDistortionMultipliers[2], vrrTransformOffset);
        
        // Map between intermediate and final resolutions
        
        // This implementation of VRR mapping assumes that blue light always maps to
        // an area closer to the center of the final image than red or green, and will break
        // if distortion coefficients don't reflect that. This assumption is based on the
        // fact that blue light bends the most sharply due to lens distortion.
        
        if (!checkingMiddleX ||
            coords_blue.x < x_lower_end ||
            coords_blue.x > x_upper_start)
        {
            correctX(coords_red);
            correctX(coords_green);
            correctX(coords_blue);
        }
        
        if (!checkingMiddleY ||
            coords_blue.y < y_lower_end ||
            coords_blue.y > y_upper_start)
        {
            correctY(coords_red);
            correctY(coords_green);
            correctY(coords_blue);
        }
        
        sampleColor(coords_red, coords_green, coords_blue, leftColor, rightColor, input);
    }
    else if (uniforms.clearingFramebuffer)
    {
        leftColor  = half4{ 0, 0, 0 };
        rightColor = half4{ 0, 0, 0 };
    }
    else
    {
        return;
    }
    
    writeColor(id, uniforms, leftColor, rightColor, output);
}

kernel void genericCorrectLensDistortion(constant LensDistortionUniforms      &uniforms [[ buffer(0) ]],
                                         constant rasterization_rate_map_data &vrrMap   [[ buffer(1) ]],
                                         
                                         texture2d_array<half, access::sample> input  [[ texture(0) ]],
                                         texture2d      <half, access::write>  output [[ texture(1) ]],
                                         
                                         ushort2 id [[ thread_position_in_grid ]])
{
    float2 clipCoords = float2(half2(id) + uniforms.clipOffset);
    float radius_squared = length_squared(clipCoords);
    
    half4 leftColor, rightColor;
    
    if (radius_squared <= uniforms.maxRadiusSquared)
    {
        half3 inverseDistortionMultipliers = createInverseDistortionMultipliers(radius_squared, uniforms);
        
        float2 coords_red   = fma(clipCoords, inverseDistortionMultipliers[0], uniforms.intermediateSideLengthHalf);
        float2 coords_green = fma(clipCoords, inverseDistortionMultipliers[1], uniforms.intermediateSideLengthHalf);
        float2 coords_blue  = fma(clipCoords, inverseDistortionMultipliers[2], uniforms.intermediateSideLengthHalf);
        
        // Map between intermediate and final resolutions
        
        rasterization_rate_map_decoder vrrDecoder(vrrMap);
        
        coords_red   = vrrDecoder.map_screen_to_physical_coordinates(coords_red);
        coords_green = vrrDecoder.map_screen_to_physical_coordinates(coords_green);
        coords_blue  = vrrDecoder.map_screen_to_physical_coordinates(coords_blue);
        
        sampleColor(coords_red, coords_green, coords_blue, leftColor, rightColor, input);

    }
    else if (uniforms.clearingFramebuffer)
    {
        leftColor  = half4{ 0, 0, 0 };
        rightColor = half4{ 0, 0, 0 };
    }
    else
    {
        return;
    }
    
    writeColor(id, uniforms, leftColor, rightColor, output);
}

kernel void correctLensDistortion_noVRR(constant LensDistortionUniforms &uniforms [[ buffer(0) ]],
                                        
                                        texture2d_array<half, access::sample> input  [[ texture(0) ]],
                                        texture2d      <half, access::write>  output [[ texture(1) ]],
                                        
                                        ushort2 id [[ thread_position_in_grid ]])
{
    float2 clipCoords = float2(half2(id) + uniforms.clipOffset);
    float radius_squared = length_squared(clipCoords);
    
    half4 leftColor, rightColor;
    
    if (radius_squared <= uniforms.maxRadiusSquared)
    {
        half3 inverseDistortionMultipliers = createInverseDistortionMultipliers(radius_squared, uniforms);
        
        float2 coords_red   = fma(clipCoords, inverseDistortionMultipliers[0], uniforms.intermediateSideLengthHalf);
        float2 coords_green = fma(clipCoords, inverseDistortionMultipliers[1], uniforms.intermediateSideLengthHalf);
        float2 coords_blue  = fma(clipCoords, inverseDistortionMultipliers[2], uniforms.intermediateSideLengthHalf);
        
        sampleColor(coords_red, coords_green, coords_blue, leftColor, rightColor, input);

    }
    else if (uniforms.clearingFramebuffer)
    {
        leftColor  = half4{ 0, 0, 0 };
        rightColor = half4{ 0, 0, 0 };
    }
    else
    {
        return;
    }
    
    writeColor(id, uniforms, leftColor, rightColor, output);
}

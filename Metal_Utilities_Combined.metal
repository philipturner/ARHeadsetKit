// This is an auto-generated file.

//
//  MemoryUtilities.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/15/21.
//
#include <metal_stdlib>

#if __METAL_MACOS__
#include <ARHeadsetKit_macOS/MemoryUtilities.h>
#else
#include <ARHeadsetKit/MemoryUtilities.h>
#endif
using namespace metal;
ushort BinarySearch::binarySearch(uint element, constant uint *list, ushort listSizeMinus1)
{
    ushort lowerBound = 0;
    ushort upperBound = listSizeMinus1;
    
    while (lowerBound != upperBound)
    {
        ushort midPoint = rhadd(lowerBound, upperBound);
        if (list[midPoint] > element)
        {
            upperBound = midPoint - 1;
        }
        else
        {
            lowerBound = midPoint;
        }
    }
    return lowerBound;
}
ushort3 DualID::pack(uint2 id)
{
    return {
        as_type<ushort4>(id)[0],
        as_type<ushort>(uchar2(as_type<uchar4>(id.x).z,
                               as_type<uchar4>(id.y).z)),
        as_type<ushort4>(id)[2]
    };
}
ushort3 DualID::pack(uint x, uint y)
{
    return {
        as_type<ushort2>(x)[0],
        as_type<ushort>(uchar2(as_type<uchar4>(x).z,
                               as_type<uchar4>(y).z)),
        as_type<ushort2>(y)[0]
    };
}
uint2 DualID::unpack(ushort3 id)
{
    ushort4 output;
    
    output[0] = id[0];
    output[2] = id[2];
    
    output[1] = as_type<ushort>(uchar2(as_type<uchar2>(id.y).x, 0));
    output[3] = as_type<ushort>(uchar2(as_type<uchar2>(id.y).y, 0));
    
    return as_type<uint2>(output);
}
uint DualID::getX(ushort3 id)
{
    ushort2 output;
    
    output[0] = id[0];
    output[1] = as_type<ushort>(uchar2(as_type<uchar2>(id.y).x, 0));
    
    return as_type<uint>(output);
}
uint DualID::getY(ushort3 id)
{
    ushort2 output;
    
    output[0] = id[2];
    output[1] = as_type<ushort>(uchar2(as_type<uchar2>(id.y).y, 0));
    
    return as_type<uint>(output);
}
void DualID::setX(device ushort3 *id, uint x)
{
    reinterpret_cast<device ushort*>(id)[0] = as_type<ushort2>(x)[0];
    reinterpret_cast<device uchar*> (id)[2] = as_type<uchar4> (x)[2];
}
void DualID::setY(device ushort3 *id, uint y)
{
    reinterpret_cast<device ushort*>(id)[2] = as_type<ushort2>(y)[0];
    reinterpret_cast<device uchar*> (id)[3] = as_type<uchar4> (y)[2];
}
uint PackedID10::get(device void *device_32_bytes, ushort index, uint bufferOffset)
{
    auto ids = reinterpret_cast<device uchar*>(device_32_bytes);
    auto selectedIDs = ids + (bufferOffset + (index << 1) + index);
    
    uchar4 output = {
        selectedIDs[0],
        selectedIDs[1],
        selectedIDs[2],
        0
    };
    
    return as_type<uint>(output);
}
void PackedID10::set(device void *device_32_bytes, ushort index, uint id, uint bufferOffset)
{
    auto ids = reinterpret_cast<device uchar*>(device_32_bytes);
    auto selectedIDs = ids + (bufferOffset + (index << 1) + index);
    
    selectedIDs[0] = as_type<uchar4>(id)[0];
    selectedIDs[1] = as_type<uchar4>(id)[1];
    selectedIDs[2] = as_type<uchar4>(id)[2];
}
namespace InternalCorrectWrite {
    template <typename T>
    void setX(device vec<T, 2> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = id << 1;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setY(device vec<T, 2> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = (id << 1) + 1;
        
        targetPointer[index] = value;
    }
    
    
    
    template <typename T>
    void setX(device vec<T, 4> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = id << 2;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setY(device vec<T, 4> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = (id << 2) + 1;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setZ(device vec<T, 4> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = (id << 2) + 2;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setW(device vec<T, 4> *pointer, uint id, T value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        uint index = (id << 2) + 3;
        
        targetPointer[index] = value;
    }
    
    
    
    template <typename T>
    void setXY(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device vec<T, 2> *>(pointer);
        uint index = id << 1;
        
        targetPointer[index] = value;
    }
    
    template <typename T>
    void setXZ(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += id << 2;
        
        targetPointer[0] = value[0];
        targetPointer[2] = value[1];
    }
    
    template <typename T>
    void setXW(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += id << 2;
        
        targetPointer[0] = value[0];
        targetPointer[3] = value[1];
    }
    
    template <typename T>
    void setYZ(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += (id << 2) + 1;
        
        targetPointer[0] = value[0];
        targetPointer[1] = value[1];
    }
    
    template <typename T>
    void setYW(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += (id << 2) + 1;
        
        targetPointer[0] = value[0];
        targetPointer[2] = value[1];
    }
    
    template <typename T>
    void setZW(device vec<T, 4> *pointer, uint id, vec<T, 2> value)
    {
        auto targetPointer = reinterpret_cast<device vec<T, 2> *>(pointer);
        uint index = (id << 1) + 1;
        
        targetPointer[index] = value;
    }
    
    
    
    template <typename T>
    void setXYZ(device vec<T, 4> *pointer, uint id, vec<T, 3> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer + id);
        
        *reinterpret_cast<device vec<T, 2> *>(targetPointer) = value.xy;
        targetPointer[2] = value.z;
    }
    
    template <typename T>
    void setXYW(device vec<T, 4> *pointer, uint id, vec<T, 3> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer + id);
        
        *reinterpret_cast<device vec<T, 2> *>(targetPointer) = value.xy;
        targetPointer[3] = value.z;
    }
    
    template <typename T>
    void setXZW(device vec<T, 4> *pointer, uint id, vec<T, 3> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer + id);
        
        targetPointer[0] = value.x;
        reinterpret_cast<device vec<T, 2> *>(targetPointer)[1] = value.yz;
    }
    
    template <typename T>
    void setYZW(device vec<T, 4> *pointer, uint id, vec<T, 3> value)
    {
        auto targetPointer = reinterpret_cast<device T*>(pointer);
        targetPointer += (id << 2) + 1;
        
        targetPointer[0] = value.x;
        *reinterpret_cast<device vec<T, 2> *>(targetPointer + 1) = value.yz;
    }
}
#define makeFunc(funcName, scalar, vecSize)                                 \
void CorrectWrite::funcName(device vec<scalar, vecSize> *pointer, uint id,  \
                                       scalar value)                        \
{                                                                           \
    InternalCorrectWrite::funcName(pointer, id, value);                     \
}                                                                           \
// forced space for concatenating files
#define makeMultiFunc(funcName, scalar, vecSize, inputSize)                 \
void CorrectWrite::funcName(device vec<scalar, vecSize> *pointer, uint id,  \
                                   vec<scalar, inputSize> value)            \
{                                                                           \
    InternalCorrectWrite::funcName(pointer, id, value);                     \
}                                                                           \
// forced space for concatenating files
#define makeFuncFamily(scalar)                                              \
makeFunc(setX, scalar, 2)                                                   \
makeFunc(setY, scalar, 2)                                                   \
                                                                            \
makeFunc(setX, scalar, 4)                                                   \
makeFunc(setY, scalar, 4)                                                   \
makeFunc(setZ, scalar, 4)                                                   \
makeFunc(setW, scalar, 4)                                                   \
                                                                            \
makeMultiFunc(setXY, scalar, 4, 2)                                          \
makeMultiFunc(setXZ, scalar, 4, 2)                                          \
makeMultiFunc(setXW, scalar, 4, 2)                                          \
makeMultiFunc(setYZ, scalar, 4, 2)                                          \
makeMultiFunc(setYW, scalar, 4, 2)                                          \
makeMultiFunc(setZW, scalar, 4, 2)                                          \
                                                                            \
makeMultiFunc(setXYZ, scalar, 4, 3)                                         \
makeMultiFunc(setXYW, scalar, 4, 3)                                         \
makeMultiFunc(setXZW, scalar, 4, 3)                                         \
makeMultiFunc(setYZW, scalar, 4, 3)                                         \
// forced space for concatenating files
makeFuncFamily(bool)
makeFuncFamily(uchar)
makeFuncFamily(ushort)
makeFuncFamily(uint)
makeFuncFamily(ulong)
makeFuncFamily(char)
makeFuncFamily(short)
makeFuncFamily(int)
makeFuncFamily(long)
makeFuncFamily(half)
makeFuncFamily(float)
//
//  ARObjectUtilities.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/11/21.
//
#include <metal_stdlib>

#if __METAL_MACOS__
#include <ARHeadsetKit_macOS/ARObjectUtilities.h>
#else
#include <ARHeadsetKit/ARObjectUtilities.h>
#endif
using namespace metal;
inline uchar getCullMask(float4 projectedVertex)
{
    uchar output = 0;
    
    if      (projectedVertex.x >  projectedVertex.w) { output |= 1 << 0; }
    else if (projectedVertex.x < -projectedVertex.w) { output |= 1 << 1; }
    
    if      (projectedVertex.y >  projectedVertex.w) { output |= 1 << 2; }
    else if (projectedVertex.y < -projectedVertex.w) { output |= 1 << 3; }
    
    if      (projectedVertex.z >= projectedVertex.w) { output |= 1 << 4; }
    else if (projectedVertex.z < 0)                  { output |= 1 << 5; }
    
    return output;
}
bool ARObjectUtilities::shouldCull(threadgroup void *tg_8bytes,
                                   float4 projectedVertex,
                                   
                                   ushort id_in_quadgroup,
                                   ushort quadgroup_id,
                                   ushort thread_id)
{
    auto tg_cullMasks = reinterpret_cast<threadgroup uchar*>(tg_8bytes);
    tg_cullMasks[thread_id] = getCullMask(projectedVertex);
    
    auto tg_reducedCullMasks = reinterpret_cast<threadgroup uchar2*>(tg_8bytes);
    
    if (id_in_quadgroup == 0)
    {
        auto selectedCullMasks = tg_cullMasks + thread_id;
        
        tg_reducedCullMasks[quadgroup_id] = uchar2(selectedCullMasks[0], selectedCullMasks[1])
                                          & uchar2(selectedCullMasks[2], selectedCullMasks[3]);
    }
    
    uchar2 combinedCullMasks = tg_reducedCullMasks[0] & tg_reducedCullMasks[1];
    
    return (combinedCullMasks[0] & combinedCullMasks[1]) != 0;
}
bool ARObjectUtilities::Serial::shouldCull(thread float4 *projectedVertices)
{
    uchar2 reducedCullMasks[4];
    auto cullMasks = reinterpret_cast<thread uchar*>(reducedCullMasks);
    
    for (ushort i = 0; i < 8; ++i)
    {
        cullMasks[i] = getCullMask(projectedVertices[i]);
    }
    
    for (ushort thread_id = 0; thread_id < 8; ++thread_id)
    {
        ushort quadgroup_id    = thread_id >> 2;
        ushort id_in_quadgroup = thread_id & 3;
        
        if (id_in_quadgroup == 0)
        {
            auto selectedCullMasks = cullMasks + thread_id;
            
            reducedCullMasks[quadgroup_id] = uchar2(selectedCullMasks[0], selectedCullMasks[1])
                                           & uchar2(selectedCullMasks[2], selectedCullMasks[3]);
        }
    }
    
    uchar2 combinedCullMasks = reducedCullMasks[0] & reducedCullMasks[1];
    
    return (combinedCullMasks[0] & combinedCullMasks[1]) != 0;
}
namespace InternalARObjectUtilities {
    float3 multiplyAffineTransform(float4x4 affineTransform, float3 input)
    {
        return fma(affineTransform[0].xyz, input.x,
               fma(affineTransform[1].xyz, input.y,
               fma(affineTransform[2].xyz, input.z,
                   affineTransform[3].xyz)));
    }
    
    float3 multiplyNormalTransform(float4x4 normalTransform, float3 input)
    {
        return fma(normalTransform[0].xyz,  input.x,
               fma(normalTransform[1].xyz,  input.y,
                   normalTransform[2].xyz * input.z));
    }
    
    float multiplyAffineTransformRow(float4x4 affineTransform, float3 input, ushort index)
    {
        return fma(affineTransform[0][index], input.x,
               fma(affineTransform[1][index], input.y,
               fma(affineTransform[2][index], input.z,
                   affineTransform[3][index])));
    }
    
    float multiplyNormalTransformRow(float4x4 normalTransform, float3 input, ushort index)
    {
        return fma(normalTransform[0][index],  input.x,
               fma(normalTransform[1][index],  input.y,
                   normalTransform[2][index] * input.z));
    }
    
    // Runs on 3 parallel threads
    bool cameraIsInside(threadgroup void *tg_3bytes,
                        float4x4 worldToModelTransform,
                        float3 objectScaleHalf, float3 objectPosition,
                        float3 cameraPosition,
                        ushort id_in_quadgroup)
    {
        auto tg_insideBoundingBox = reinterpret_cast<threadgroup bool*>(tg_3bytes);
        
        float thread_coord = multiplyAffineTransformRow(worldToModelTransform, cameraPosition, id_in_quadgroup);
        
        float objectScaleHalfCoord = objectScaleHalf[id_in_quadgroup];
        float objectPositionCoord  = objectPosition [id_in_quadgroup];
        
        tg_insideBoundingBox[id_in_quadgroup] = abs(thread_coord - objectPositionCoord) < objectScaleHalfCoord;
        
        return all({ tg_insideBoundingBox[0], tg_insideBoundingBox[1], tg_insideBoundingBox[2] });
    }
    
    typedef struct {
        float4 deltaWithLengthInverse;
        float3 position;
    } AxisData;
    
    AxisData getAxisData(float3 delta, float3 centerPosition)
    {
        float3 position = delta + centerPosition;
        
        float distanceSquared = length_squared(position);
        float centerDistanceSquared = length_squared(centerPosition);
        
        if (distanceSquared > centerDistanceSquared)
        {
            float3 newPosition = centerPosition - delta;
            float  newDistanceSquared = length_squared(newPosition);
            
            if (newDistanceSquared < distanceSquared) {
                delta = -delta;
                position = newPosition;
                distanceSquared = newDistanceSquared;
            }
        }
        
        return { float4(delta, precise::rsqrt(length_squared(delta))), position };
    }
    
    float getSideDistanceSquared(AxisData thread_axisData,
                                 float3 altDelta1, float altDelta1_inverseLength,
                                 float3 altDelta2, float altDelta2_inverseLength)
    {
        float3 planeNormal = thread_axisData.deltaWithLengthInverse.xyz
                           * thread_axisData.deltaWithLengthInverse.w;
        float3 planeOrigin = thread_axisData.position;
        
        float3 projectedPoint = fma(dot(planeOrigin, planeNormal), planeNormal, -planeOrigin);
        
        
        
        float component1 = dot(projectedPoint, altDelta1) * altDelta1_inverseLength;
        float component2 = dot(projectedPoint, altDelta2) * altDelta2_inverseLength;
        
        float normalizedComponent2 = component2 * altDelta2_inverseLength;
        
        float3 closestPoint;
        
        if (component1 * altDelta1_inverseLength > 1)
        {
            closestPoint = (normalizedComponent2 > 1)
                         ? altDelta1 + altDelta2
                         : fma(altDelta2, component2 * altDelta2_inverseLength, altDelta1);
        }
        else
        {
            closestPoint = (normalizedComponent2 > 1)
                         ? closestPoint = fma(altDelta1, component1 * altDelta1_inverseLength, altDelta2)
                         : projectedPoint;
        }
        return length_squared(closestPoint + planeOrigin);
    }
    
    // Runs on 3 parallel threads
    void getDistancesSquared(threadgroup void *tg_32bytes_distancesSquared,
                             float4x4 modelToWorldTransform,
                             float4x4 worldToCameraTransform,
                             float3 objectScaleHalf, float3 objectPosition,
                             ushort id_in_quadgroup)
    {
        auto tg_floatArray = reinterpret_cast<threadgroup float*>(tg_32bytes_distancesSquared);
        
        tg_floatArray[id_in_quadgroup] = multiplyAffineTransformRow(modelToWorldTransform, objectPosition, id_in_quadgroup);
        float3 lastColumn(tg_floatArray[0], tg_floatArray[1], tg_floatArray[2]);
        
        tg_floatArray[id_in_quadgroup] = multiplyAffineTransformRow(worldToCameraTransform, lastColumn, id_in_quadgroup);
        float3 centerPosition(tg_floatArray[0], tg_floatArray[1], tg_floatArray[2]);
        
        float3 delta = modelToWorldTransform.columns[id_in_quadgroup].xyz * objectScaleHalf[id_in_quadgroup];
        delta        = multiplyNormalTransform(worldToCameraTransform, delta);
        
        
        
        auto thread_axisData = getAxisData(delta, centerPosition);
        
        float4 altDeltaData[2];
        ushort altDeltaDataCounter = 0;
        
        auto tg_deltaData = reinterpret_cast<threadgroup float4*>(tg_32bytes_distancesSquared);
        
        for (uchar i = 0; i < 3; ++i)
        {
            if (id_in_quadgroup == i)
            {
                *tg_deltaData = thread_axisData.deltaWithLengthInverse;
            }
            if (!(id_in_quadgroup == i))
            {
                altDeltaData[altDeltaDataCounter] = *tg_deltaData;
                altDeltaDataCounter += 1;
            }
        }
        
        tg_floatArray[id_in_quadgroup] = getSideDistanceSquared(thread_axisData,
                                                                altDeltaData[0].xyz, altDeltaData[0].w,
                                                                altDeltaData[1].xyz, altDeltaData[1].w);
    }
    
    namespace Serial {
        bool cameraIsInside(float4x4 worldToModelTransform,
                            float3 objectScaleHalf, float3 objectPosition,
                            float3 cameraPosition)
        {
            bool3 isInsideBoundingBox;
            
            for (ushort i = 0; i < 3; ++i)
            {
                float thread_coord = multiplyAffineTransformRow(worldToModelTransform, cameraPosition, i);
                
                float objectScaleHalfCoord = objectScaleHalf[i];
                float objectPositionCoord  = objectPosition [i];
                
                isInsideBoundingBox[i] = abs(thread_coord - objectPositionCoord) < objectScaleHalfCoord;
            }
            
            return all(isInsideBoundingBox);
        }
        
        void getDistancesSquared(thread float3 &t_12bytes_distancesSquared,
                                 float4x4 modelToWorldTransform,
                                 float4x4 worldToCameraTransform,
                                 float3 objectScaleHalf, float3 objectPosition)
        {
            thread float3 &t_12bytes = t_12bytes_distancesSquared;
            
            for (ushort i = 0; i < 3; ++i)
            {
                t_12bytes[i] = multiplyAffineTransformRow(modelToWorldTransform, objectPosition, i);
            }
            
            float3 lastColumn = t_12bytes;
            
            for (ushort i = 0; i < 3; ++i)
            {
                t_12bytes[i] = multiplyAffineTransformRow(worldToCameraTransform, lastColumn, i);
            }
            
            float3 centerPosition = t_12bytes;
            AxisData axisData[3];
            
            for (ushort i = 0; i < 3; ++i)
            {
                float3 delta = modelToWorldTransform.columns[i].xyz * objectScaleHalf[i];
                delta        = multiplyNormalTransform(worldToCameraTransform, delta);
                
                axisData[i] = getAxisData(delta, centerPosition);
            }
            
            
            
            for (ushort id_in_quadgroup = 0; id_in_quadgroup < 3; ++id_in_quadgroup)
            {
                float4 altDeltaData[2];
                ushort altDeltaDataCounter = 0;
                
                for (uchar i = 0; i < 3; ++i)
                {
                    if (!(id_in_quadgroup == i))
                    {
                        altDeltaData[altDeltaDataCounter] = axisData[i].deltaWithLengthInverse;
                        altDeltaDataCounter += 1;
                    }
                }
                
                t_12bytes[id_in_quadgroup] = getSideDistanceSquared(axisData[id_in_quadgroup],
                                                                    altDeltaData[0].xyz, altDeltaData[0].w,
                                                                    altDeltaData[1].xyz, altDeltaData[1].w);
            }
        }
    }
}
using namespace InternalARObjectUtilities;
LOD ARObjectUtilities::getLOD(threadgroup void *tg_64bytes,
                              float4x4 modelToWorldTransform,
                              float4x4 worldToModelTransform,
                              constant float4x4 *worldToCameraTransforms,
                              constant float3   *cameraPositions,
                              bool usingHeadsetMode,
                              
                              constant ushort2 *axisMaxScaleIndices,
                              float3 objectScaleHalf, float3 objectPosition,
                              
                              ushort id_in_quadgroup,
                              ushort quadgroup_id,
                              ushort thread_id)
{
    auto tg_32bytes = reinterpret_cast<threadgroup ulong4*>(tg_64bytes) + quadgroup_id;
    ushort transformIndex = usingHeadsetMode ? quadgroup_id : 0;
    auto tg_cameraIsInside = reinterpret_cast<threadgroup bool*>(tg_64bytes);
    
    if (id_in_quadgroup < 3)
    {
        tg_cameraIsInside[quadgroup_id] = cameraIsInside(tg_32bytes, worldToModelTransform,
                                                         objectScaleHalf, objectPosition,
                                                         cameraPositions[transformIndex], id_in_quadgroup);
    }
    
    if (tg_cameraIsInside[0] || tg_cameraIsInside[1]) { return 65535; }
    
    
    
    auto tg_desiredLOD = reinterpret_cast<threadgroup float*>(tg_64bytes);
    
    if (id_in_quadgroup < 3)
    {
        constant float4x4 &worldToCameraTransform = *(worldToCameraTransforms + transformIndex);
        
        getDistancesSquared(tg_32bytes,
                            modelToWorldTransform,
                            worldToCameraTransform,
                            objectScaleHalf, objectPosition,
                            id_in_quadgroup);
        
        ushort2 scaleIndices = axisMaxScaleIndices[id_in_quadgroup];
        float maxScaleHalf = max(objectScaleHalf[scaleIndices[0]], objectScaleHalf[scaleIndices[1]]);
        float maxScale = maxScaleHalf + maxScaleHalf;
        
        auto tg_distancesSquared = reinterpret_cast<threadgroup float*>(tg_64bytes);
        float minDistanceSquared = min(tg_distancesSquared[id_in_quadgroup], tg_distancesSquared[8 + id_in_quadgroup]);
        
        float powOperand, powPower;
        
        if (quadgroup_id == 0)
        {
            powOperand = maxScale;
            powPower = 1.0 / 3;
        }
        else
        {
            powOperand = minDistanceSquared;
            powPower = -0.5;
        }
        
        float powResult = fast::powr(powOperand, powPower);
        
        auto shuffledDownPowResults = reinterpret_cast<threadgroup float*>(tg_64bytes);
        
        if (quadgroup_id == 1)
        {
            shuffledDownPowResults[id_in_quadgroup] = powResult;
        }
        if (!(quadgroup_id == 1))
        {
            float retrievedPowResult = shuffledDownPowResults[id_in_quadgroup];
            float desiredLOD = powResult * retrievedPowResult * (40 * M_PI_F);
            
            tg_desiredLOD[id_in_quadgroup] = desiredLOD;
        }
    }
    
    float desiredLOD = max3(tg_desiredLOD[0], tg_desiredLOD[1], tg_desiredLOD[2]);
    
    return (desiredLOD <= 65534) ? LOD(desiredLOD) : 65534;
}
using namespace InternalARObjectUtilities::Serial;
LOD ARObjectUtilities::Serial::getLOD(float4x4 modelToWorldTransform,
                                      float4x4 worldToModelTransform,
                                      constant float4x4 *worldToCameraTransforms,
                                      constant float3   *cameraPositions,
                                      bool usingHeadsetMode,
                                      
                                      constant ushort2 *axisMaxScaleIndices,
                                      float3 objectScaleHalf, float3 objectPosition)
{
    ushort numTransforms = select(1, 2, usingHeadsetMode);
    for (ushort transformIndex = 0; transformIndex < numTransforms; ++transformIndex)
    {
        if (cameraIsInside(worldToModelTransform,
                           objectScaleHalf, objectPosition,
                           cameraPositions[transformIndex]))
        {
            return 65535;
        }
    }
    
    float3 minDistancesSquared(FLT_MAX);
    
    for (ushort transformIndex = 0; transformIndex < numTransforms; ++transformIndex)
    {
        constant float4x4 &worldToCameraTransform = *(worldToCameraTransforms + transformIndex);
        float3 currentDistancesSquared;
        
        getDistancesSquared(currentDistancesSquared,
                            modelToWorldTransform,
                            worldToCameraTransform,
                            objectScaleHalf, objectPosition);
        
        minDistancesSquared = min(minDistancesSquared, currentDistancesSquared);
    }
    
    
    
    float3 maxScales;
    
    for (ushort id_in_quadgroup = 0; id_in_quadgroup < 3; ++id_in_quadgroup)
    {
        ushort2 scaleIndices = axisMaxScaleIndices[id_in_quadgroup];
        float maxScaleHalf = max(objectScaleHalf[scaleIndices[0]], objectScaleHalf[scaleIndices[1]]);
        maxScales[id_in_quadgroup] = maxScaleHalf + maxScaleHalf;
    }
    
    float3 desiredLODs = fast::powr(maxScales, 1.0 / 3) * fast::rsqrt(minDistancesSquared);
    float desiredLOD = max3(desiredLODs[0], desiredLODs[1], desiredLODs[2]) * (40 * M_PI_F);
    
    return (desiredLOD <= 65534) ? LOD(desiredLOD) : 65534;
}
//
//  ColorUtilities.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/24/21.
//
#include <metal_stdlib>

#if __METAL_MACOS__
#include <ARHeadsetKit_macOS/ColorUtilities.h>
#else
#include <ARHeadsetKit/ColorUtilities.h>
#endif
using namespace metal;
half3 ColorUtilities::convertYCbCr_toRGB(half2 chroma, half luma)
{
    half3 out;
    
    out.rg = fma(half2(1.4020, -0.7141), chroma.g, half2(-0.7017, 0.5291));
    out.b = luma - 0.8860;
    
    out.gb = fma(half2(-0.3441, 1.7720), chroma.r, out.gb);
    out.rg += half2(luma);
    
    return out;
}
half3 ColorUtilities::getLightContribution(half3 lightDirection,
                                           half3 directionalLightColor,
                                           half3 ambientLightColor,
                                           half  shininess,
                                           
                                           half  normal_lengthSquared,
                                           half3 normal_notNormalized,
                                           half  eyeDirection_lengthSquared,
                                           half3 eyeDirection_notNormalized)
{
    half eyeDirectionMultiplier = rsqrt(eyeDirection_lengthSquared);
    half normalMultiplier       = rsqrt(normal_lengthSquared);
    
    half3 halfwayVector_notNormalized = fma(eyeDirection_notNormalized, eyeDirectionMultiplier, lightDirection);
    half directionalLightContribution = dot(normal_notNormalized,                               lightDirection);
    
    half halfwayVectorMultiplier = length_squared(halfwayVector_notNormalized);
    half reflectionAngleCosine   = dot(normal_notNormalized, halfwayVector_notNormalized);
    
    directionalLightContribution = saturate(directionalLightContribution * normalMultiplier);
    reflectionAngleCosine *= normalMultiplier;
    
    if (reflectionAngleCosine > (1 / 256.0) * halfwayVectorMultiplier && halfwayVectorMultiplier >= HALF_MIN)
    {
        reflectionAngleCosine *= fast::rsqrt(float(halfwayVectorMultiplier));
        directionalLightContribution += fast::powr(float(reflectionAngleCosine), float(shininess));
    }
    
    if (directionalLightContribution > 0)
    {
        return fma(directionalLightColor, directionalLightContribution, ambientLightColor);
    }
    else
    {
        return ambientLightColor;
    }
}
namespace InternalColorUtilities {
    template <typename T, T modify(T lhs, T rhs)>
    bool attemptAtomicallyModify(T lhs, device atomic_uint *rhs)
    {
        uint old_rhs;
        old_rhs = atomic_load_explicit(rhs, memory_order_relaxed);
        
        uint new_rhs = as_type<uint>(modify(lhs, as_type<T>(old_rhs)));
        
        return atomic_compare_exchange_weak_explicit(rhs, &old_rhs, new_rhs,
                                                     memory_order_relaxed, memory_order_relaxed);
    }
    template <typename T, T modify(T lhs, T rhs)>
    bool attemptAtomicallyModify(device atomic_uint *lhs, T rhs)
    {
        uint old_lhs;
        old_lhs = atomic_load_explicit(lhs, memory_order_relaxed);
        
        uint new_lhs = as_type<uint>(modify(as_type<T>(old_lhs), rhs));
        
        return atomic_compare_exchange_weak_explicit(lhs, &old_lhs, new_lhs,
                                                     memory_order_relaxed, memory_order_relaxed);
    }
    template <typename T, T modify(T lhs, T mid, T rhs)>
    bool attemptAtomicallyModify(T lhs, device atomic_uint *mid, T rhs)
    {
        uint old_mid;
        old_mid = atomic_load_explicit(mid, memory_order_relaxed);
        
        uint new_mid = as_type<uint>(modify(as_type<T>(old_mid), mid));
        
        return atomic_compare_exchange_weak_explicit(mid, &old_mid, new_mid,
                                                     memory_order_relaxed, memory_order_relaxed);
    }
    
    template<typename T> T add       (T lhs, T rhs) { return lhs + rhs; }
    template<typename T> T subtract  (T lhs, T rhs) { return lhs - rhs; }
    template<typename T> T multiply  (T lhs, T rhs) { return lhs * rhs; }
    template<typename T> T fma(T lhs, T mid, T rhs) { return fma(lhs, mid, rhs); }
}
using namespace InternalColorUtilities;
bool ColorUtilities::attemptAtomicallyAddHalf(half2 lhs, device atomic_uint *rhs)
{
    return attemptAtomicallyModify<half2, add>(lhs, rhs);
}
using namespace SceneColorReconstruction;
Texel YCbCrTexture::read(ushort2 texCoords) const
{
    uint chromaRowOffset = uint(texCoords.y) << 13;
    uint chromaIndex = chromaRowOffset + texCoords.x;
    uchar2 sampleChroma = chromaRows[chromaIndex];
    
    uint lumaIndex = chromaIndex + chromaRowOffset;
    uchar4 sampleLuma(lumaRows[lumaIndex], lumaRows[lumaIndex + 8192]);
    
    return { sampleLuma, sampleChroma };
}
void YCbCrTexture::write(Texel input, ushort2 texCoords)
{
    uint chromaRowOffset = uint(texCoords.y) << 13;
    uint chromaIndex = chromaRowOffset + texCoords.x;
    chromaRows[chromaIndex] = input.chroma;
    
    uint lumaIndex = chromaIndex + chromaRowOffset;
    lumaRows[lumaIndex]        = input.luma.xy;
    lumaRows[lumaIndex + 8192] = input.luma.zw;
}
void YCbCrTexture::createPadding(Texel input, ushort2 texCoords,
                                 ushort lastHeight, ushort currentHeight, ushort nextHeight,
                                 ushort offsetY, thread ushort &nextOffsetY)
{
#define TRANSFER_TEXEL_DATA(components, offsetX, offsetY)                               \
write({ input.luma.components, input.chroma }, texCoords + ushort2(offsetX, offsetY));  \
// forced space for concatenating files
    if (offsetY == 0)
    {
        TRANSFER_TEXEL_DATA(xyxy, 0, -1);
        
        if (lastHeight == 0) { TRANSFER_TEXEL_DATA(xxxx, -1, -1); }
        if (nextHeight == 0) { TRANSFER_TEXEL_DATA(yyyy,  1, -1); }
    }
    
    if (offsetY > lastHeight || lastHeight == 0) { TRANSFER_TEXEL_DATA(xxzz, -1, 0); }
    if (offsetY > nextHeight || nextHeight == 0) { TRANSFER_TEXEL_DATA(yyww,  1, 0); }
    
    nextOffsetY = offsetY + 1;
    
    if (nextOffsetY == currentHeight)
    {
        TRANSFER_TEXEL_DATA(zwzw, 0, 1);
        
        if (nextOffsetY > lastHeight || lastHeight == 0) { TRANSFER_TEXEL_DATA(zzzz, -1, 1); }
        if (nextOffsetY > nextHeight || nextHeight == 0) { TRANSFER_TEXEL_DATA(wwww,  1, 1); }
    }
}

//
//  ARObjectUtilities.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/11/21.
//

#include <metal_stdlib>
#include "../ARObjectUtilities.h"
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

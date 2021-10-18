//
//  ARObjectUtilities.h
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/11/21.
//

#ifndef ARObjectUtilities_h
#define ARObjectUtilities_h

#include <metal_stdlib>
using namespace metal;

typedef ushort LOD;

namespace ARObjectUtilities {
    /// Runs on 8 parallel threads. Only call this in an optimized shader for devices with at least the `.apple4` GPU family.
    bool shouldCull(threadgroup void *tg_8bytes,
                    float4 projectedVertex,
                    
                    ushort id_in_quadgroup,
                    ushort quadgroup_id,
                    ushort thread_id);
    
    /// Runs on 8 parallel threads. Only call this in an optimized shader for devices with at least the `.apple4` GPU family.
    ushort getLOD(threadgroup void *tg_64bytes,
                  float4x4 modelToWorldTransform,
                  float4x4 worldToModelTransform,
                  constant float4x4 *worldToCameraTransforms,
                  constant float3   *cameraPositions,
                  bool usingHeadsetMode,
                  
                  constant ushort2 *axisMaxScaleIndices,
                  float3 objectScaleHalf, float3 objectPosition,
                  
                  ushort id_in_quadgroup,
                  ushort quadgroup_id,
                  ushort thread_id);
    
    // Although devices in the `.apple3` GPU family support using threadgroup memory, the back-end
    // Metal compiler fails every time shaders using threadgroup memory are loaded at runtime.
    // So, slower compute shaders that don't use threadgroup memory are used for these devices.
    namespace Serial {
        /// Runs on one thread. Only call this in a separate shader for compatibility with devices in `.apple3 ` GPU family. `.apple1` and `.apple2` have not been tested and may cause undefined behavior.
        bool shouldCull(thread float4 *projectedVertices);
        
        /// Runs on one thread. Only call this in a separate shader for compatibility with devices in `.apple3 ` GPU family. `.apple1` and `.apple2` have not been tested and may cause undefined behavior.
        ushort getLOD(float4x4 modelToWorldTransform,
                      float4x4 worldToModelTransform,
                      constant float4x4 *worldToCameraTransforms,
                      constant float3   *cameraPositions,
                      bool usingHeadsetMode,
                      
                      constant ushort2 *axisMaxScaleIndices,
                      float3 objectScaleHalf, float3 objectPosition);
    };
}

#endif /* ARObjectUtilities_h */

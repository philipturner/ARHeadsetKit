//
//  SceneOcclusionTesting.metal.metal
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#include <metal_stdlib>
using namespace metal;

typedef struct {
    float4 position [[position]];
    uint   triangleID;
} VertexInOut;



vertex VertexInOut occlusionVertexTransform(const device float4 *vertices       [[ buffer(0) ]],
                                            const device uint   *vertexOffsets  [[ buffer(1) ]],
                                            const device uint   *reducedIndices [[ buffer(2) ]],
                                            const device uint   *triangleIDs    [[ buffer(3) ]],
                                            
                                            uint   iid [[ instance_id ]],
                                            ushort vid [[ vertex_id ]])
{
    uint triangleID = triangleIDs[iid];
    
    uint reducedIndex   = reducedIndices[(triangleID << 2) + vid];
    uint occlusionIndex = vertexOffsets[reducedIndex];
    
    return { vertices[occlusionIndex], triangleID };
}



[[early_fragment_tests]]
fragment uint occlusionFragmentShader(VertexInOut in [[ stage_in ]])
{
    return in.triangleID;
}

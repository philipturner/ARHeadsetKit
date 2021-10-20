//
//  SceneCullingExecution.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

#if !os(macOS)
import Metal
import simd

extension SceneCuller {
    
    func determineSectorInclusions() {
        typealias VertexUniforms = SceneRenderer.VertexUniforms
        let vertexUniforms = uniformBuffer[.vertexUniform].assumingMemoryBound(to: VertexUniforms.self)[renderIndex]
        
        var sectorInclusionsPointer = smallSectorBuffer[.inclusions].assumingMemoryBound(to: Bool.self)
        sectorInclusionsPointer += smallSectorBufferOffset
        
        for i in 0..<octreeNodeCenters.count {
            let center = simd_float4(octreeNodeCenters[i], 0)
            
            func getVisibility(using transform: simd_float4x4) -> Bool {
                var lowerCorners = simd_float4x4(
                    center + simd_float4(-1, -1, -1, 1),
                    center + simd_float4(-1, -1,  1, 1),
                    center + simd_float4(-1,  1, -1, 1),
                    center + simd_float4(-1,  1,  1, 1)
                )
                
                var upperCorners = simd_float4x4(
                    center + simd_float4( 1, -1, -1, 1),
                    center + simd_float4( 1, -1,  1, 1),
                    center + simd_float4( 1,  1, -1, 1),
                    center + simd_float4( 1,  1,  1, 1)
                )
                
                @inline(__always)
                func transformHalf(_ input: inout simd_float4x4) {
                    input[0] = transform * input[0]
                    input[1] = transform * input[1]
                    input[2] = transform * input[2]
                    input[3] = transform * input[3]
                }
                
                transformHalf(&lowerCorners)
                transformHalf(&upperCorners)
                
                let projectedCorners = ARObject.ProjectedCorners(lowerCorners: lowerCorners,
                                                                 upperCorners: upperCorners)
                return projectedCorners.areVisible
            }
            
            if getVisibility(using: vertexUniforms.viewProjectionTransform) {
                sectorInclusionsPointer[i] = true
                continue
            }
            
            sectorInclusionsPointer[i] = getVisibility(using: vertexUniforms.cameraProjectionTransform)
        }
    }
    
    func cullScene(doingColorUpdate: Bool) {
        determineSectorInclusions()
        
        let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer.optLabel = "Scene Culling Command Buffer"
        
        let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
        blitEncoder.optLabel = "Scene Culling - Clear Mark And Count Buffers"
        
        let numTriangle8Groups  = (preCullTriangleCount + 7) >> 3
        let num8192Groups       = (preCullTriangleCount + 8191) >> 13
        let num8Groups_expanded = num8192Groups << 10
        
        if numTriangle8Groups < num8Groups_expanded {
            let fillStart = numTriangle8Groups  * MemoryLayout<simd_uchar4>.stride
            let fillEnd   = num8Groups_expanded * MemoryLayout<simd_uchar4>.stride
            
            blitEncoder.fill(buffer: bridgeBuffer, layer: .counts8, range: fillStart..<fillEnd, value: 0)
        }
        
        let numVertex8Groups = (preCullVertexCount + 7) >> 3
        
        let fillSize = numVertex8Groups << 3 * MemoryLayout<UInt8>.stride
        blitEncoder.fill(buffer: vertexDataBuffer, layer: .inclusionData, range: 0..<fillSize,      value: 0)
        blitEncoder.fill(buffer: vertexDataBuffer, layer: .mark,          range: 0..<fillSize << 1, value: 0)
        
        blitEncoder.endEncoding()
        
        
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Scene Culling - Compute Pass"
        
        computeEncoder.setBuffer(uniformBuffer, layer: .vertexUniform,        offset: vertexUniformOffset,        index: 0)
        computeEncoder.setBuffer(uniformBuffer, layer: .preCullVertexCount,   offset: preCullVertexCountOffset,   index: 1)
        computeEncoder.setBuffer(uniformBuffer, layer: .preCullTriangleCount, offset: preCullTriangleCountOffset, index: 2)
        computeEncoder.setBuffer(reducedVertexBuffer,                         offset: 0,                          index: 3)
        computeEncoder.setBuffer(reducedIndexBuffer,                          offset: 0,                          index: 4)
        
        computeEncoder.pushOptDebugGroup("Mark Culls")
        
        let doing8bitSectorIDs = octreeNodeCenters.count <= 255
        
        computeEncoder.setComputePipelineState(doing8bitSectorIDs ? markVertexCulls_8bitPipelineState
                                                                  : markVertexCulls_16bitPipelineState)
        computeEncoder.setBuffer(vertexDataBuffer,  layer: .inclusionData,                               index: 5)
        
        computeEncoder.setBuffer(sectorIDBuffer,    layer: .vertexGroupMask,                             index: 6)
        computeEncoder.setBuffer(sectorIDBuffer,    layer: .vertexGroup,                                 index: 7)
        computeEncoder.setBuffer(smallSectorBuffer, layer: .inclusions, offset: smallSectorBufferOffset, index: 8)
        computeEncoder.dispatchThreadgroups([ numVertex8Groups ], threadsPerThreadgroup: 1);
        
        computeEncoder.setComputePipelineState(doing8bitSectorIDs ? markTriangleCulls_8bitPipelineState
                                                                  : markTriangleCulls_16bitPipelineState)
        computeEncoder.setBuffer(sectorIDBuffer,    layer: .triangleGroupMask,   index: 6, bound: true)
        computeEncoder.setBuffer(sectorIDBuffer,    layer: .triangleGroup,       index: 7, bound: true)
        
        computeEncoder.setBuffer(vertexDataBuffer,  layer: .mark,                index: 9)
        computeEncoder.setBuffer(bridgeBuffer,      layer: .triangleInclusions8, index: 11)
        computeEncoder.dispatchThreadgroups([ numTriangle8Groups ], threadsPerThreadgroup: 1)

        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Count Culls")
        
        computeEncoder.setComputePipelineState(countCullMarks8PipelineState)
        computeEncoder.setBuffer(vertexDataBuffer, layer: .inclusions8, index: 10)
        computeEncoder.setBuffer(bridgeBuffer,     layer: .counts8,     index: 12)
        computeEncoder.dispatchThreadgroups([ numTriangle8Groups ], threadsPerThreadgroup: 1)

        computeEncoder.setComputePipelineState(countCullMarks32to128PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts32, index: 13)
        computeEncoder.dispatchThreadgroups([ num8192Groups << 8 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts32,  index: 12, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts128, index: 13, bound: true)
        computeEncoder.dispatchThreadgroups([ num8192Groups << 6 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(countCullMarks512PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts512, index: 14)
        computeEncoder.dispatchThreadgroups([ num8192Groups << 4 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(countCullMarks2048to8192PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts2048, index: 15)
        computeEncoder.dispatchThreadgroups([ num8192Groups << 2 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts2048, index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts8192, index: 15, bound: true)
        computeEncoder.dispatchThreadgroups([ num8192Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Scan Culls")

        computeEncoder.setComputePipelineState(scanSceneCullsPipelineState)
        computeEncoder.setBuffer(bridgeBuffer,  layer: .offsets8192,         index: 16)
        computeEncoder.setBuffer(uniformBuffer, layer: .triangleVertexCount, index: 17)
        computeEncoder.dispatchThreadgroups(1, threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Mark Cull Offsets")
            
        computeEncoder.setComputePipelineState(markCullOffsets8192to2048PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets2048, index: 15, bound: true)
        computeEncoder.dispatchThreadgroups([ num8192Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets2048, index: 16, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets512,  index: 15, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts512,   index: 14, bound: true)
        computeEncoder.dispatchThreadgroups([ (preCullTriangleCount + 2047) >> 11 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setComputePipelineState(markCullOffsets512to32PipelineState)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets128, index: 14, bound: true)
        computeEncoder.dispatchThreadgroups([ (preCullTriangleCount + 511) >> 9 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets128, index: 15, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets32,  index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts32,   index: 13, bound: true)
        computeEncoder.dispatchThreadgroups([ (preCullTriangleCount + 127) >> 7 ], threadsPerThreadgroup: 1)
        
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets32, index: 15, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .offsets8,  index: 14, bound: true)
        computeEncoder.setBuffer(bridgeBuffer, layer: .counts8,   index: 13, bound: true)
        computeEncoder.dispatchThreadgroups([ (preCullTriangleCount + 31) >> 5 ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.pushOptDebugGroup("Condense Geometry")
        
        if usingHeadsetMode {
            computeEncoder.setComputePipelineState(condenseVRVerticesPipelineState)
            computeEncoder.setBuffer(uniformBuffer, layer: .headsetModeUniform, offset: headsetModeUniformOffset, index: 1)
        } else {
            computeEncoder.setComputePipelineState(condenseVerticesPipelineState)
        }
        computeEncoder.setBuffer(vertexDataBuffer, layer: .renderOffset,    index: 5, bound: true)
        computeEncoder.setBuffer(vertexDataBuffer, layer: .occlusionOffset, index: 9, bound: true)
        
        computeEncoder.setBuffer(vertexBuffer,     layer: .renderVertex,    index: 6)
        computeEncoder.setBuffer(vertexBuffer,     layer: .occlusionVertex, index: 7)
        computeEncoder.setBuffer(vertexBuffer,     layer: .videoFrameCoord, index: 8)
        computeEncoder.dispatchThreadgroups([ numVertex8Groups ], threadsPerThreadgroup: 1)
        
        if doingColorUpdate {
            computeEncoder.setComputePipelineState(condenseTrianglesForColorUpdatePipelineState)
        } else {
            computeEncoder.setComputePipelineState(condenseTrianglesPipelineState)
        }
        computeEncoder.setBuffer(renderTriangleIDBuffer,    offset: 0, index: 0)
        computeEncoder.setBuffer(occlusionTriangleIDBuffer, offset: 0, index: 1)
        computeEncoder.dispatchThreadgroups([ numTriangle8Groups ], threadsPerThreadgroup: 1)
        
        computeEncoder.popOptDebugGroup()
        computeEncoder.endEncoding()

        commandBuffer.commit()
    }
    
}
#endif

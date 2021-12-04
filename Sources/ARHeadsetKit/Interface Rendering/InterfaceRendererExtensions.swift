//
//  InterfaceRendererExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/28/21.
//

#if !os(macOS)
import Metal
import simd

public extension InterfaceRenderer {
    
    internal func initializeFrameData() {
        opaqueAliases.removeAll(keepingCapacity: true)
        transparentAliases.removeAll(keepingCapacity: true)
    }
    
    func render(element: ARInterfaceElement) {
        guard shouldPresent(element: element) else { return }
        
        let alias = element.alias
        
        if alias.surfaceOpacity == 1, alias.fragmentUniforms.textOpacity == 1 {
            opaqueAliases.append(alias)
        } else {
            transparentAliases.append(alias)
        }
    }
    
    @inlinable
    func render(elements: [ARInterfaceElement]) {
        elements.forEach(render(element:))
    }
    
}

extension InterfaceRenderer: GeometryRenderer {
    
    func updateResources() {
        assert(shouldRenderToDisplay)
        
        numRenderedElements = opaqueAliases.count + transparentAliases.count
        guard numRenderedElements > 0 else { return }
        
        ensureBufferCapacity(type: .uniform, capacity: numRenderedElements)
        
        let rawVertexUniformPointer  = uniformBuffer[.vertexUniform]   + vertexUniformOffset
        let rawFragmentUniformBuffer = uniformBuffer[.fragmentUniform] + fragmentUniformOffset
        var fragmentUniformPointer   = rawFragmentUniformBuffer.assumingMemoryBound(to: FragmentUniforms.self)
        
        @inline(__always)
        func setUniforms<T: InterfaceVertexUniforms>(_ type: T.Type) {
            var vertexUniformPointer = rawVertexUniformPointer.assumingMemoryBound(to: T.self)
            
            for alias in opaqueAliases {
                vertexUniformPointer.pointee   = T(interfaceRenderer: self, alias: alias)
                fragmentUniformPointer.pointee = alias.fragmentUniforms
                
                vertexUniformPointer   += 1
                fragmentUniformPointer += 1
            }
            
            for alias in transparentAliases {
                vertexUniformPointer.pointee   = T(interfaceRenderer: self, alias: alias)
                fragmentUniformPointer.pointee = alias.fragmentUniforms
                
                vertexUniformPointer   += 1
                fragmentUniformPointer += 1
            }
        }
        
        if usingHeadsetMode {
            setUniforms(HeadsetModeUniforms.self)
        } else {
            setUniforms(VertexUniforms.self)
        }
        
        
        
        opaqueElementGroupCounts.removeAll(keepingCapacity: true)
        var numOpaqueElements = opaqueAliases.count
        
        while numOpaqueElements > 255 {
            opaqueElementGroupCounts.append(255)
            numOpaqueElements -= 255
        }
        
        if numOpaqueElements > 0 {
            opaqueElementGroupCounts.append(numOpaqueElements)
        }
        
        transparentElementGroupCounts.removeAll(keepingCapacity: true)
        var numTransparentElements = transparentAliases.count
        
        if numTransparentElements > 0 {
            if numOpaqueElements != 255 {
                let firstTransparentElementGroupSize = min(numTransparentElements, 255 - numOpaqueElements)
                transparentElementGroupCounts.append(firstTransparentElementGroupSize)
                numTransparentElements -= firstTransparentElementGroupSize
            }
            
            while numTransparentElements > 255 {
                transparentElementGroupCounts.append(255)
                numTransparentElements -= 255
            }
            
            if numTransparentElements > 0 {
                transparentElementGroupCounts.append(numTransparentElements)
            }
        }
        
        
        
        let commandBuffer = renderer.commandQueue.makeDebugCommandBuffer()
        commandBuffer.optLabel = "Interface Surface Mesh Construction Command Buffer"
        
        let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
        computeEncoder.optLabel = "Interface Surface Mesh Construction - Compute Pass"
        
        computeEncoder.pushOptDebugGroup("Create Interface Surface Meshes")
        
        if usingHeadsetMode {
            computeEncoder.setComputePipelineState(createHeadsetModeSurfaceMeshesPipelineState)
        } else {
            computeEncoder.setComputePipelineState(createSurfaceMeshesPipelineState)
        }
        
        var numSurfacesTimes256 = numRenderedElements << 8
        computeEncoder.setBytes(&numSurfacesTimes256, length: 4, index: 2)
        
        computeEncoder.setBuffer(uniformBuffer,  layer: .vertexUniform, offset: vertexUniformOffset, index: 0)
        computeEncoder.setBuffer(geometryBuffer, layer: .cornerNormal,                               index: 1)
        
        computeEncoder.setBuffer(uniformBuffer,  layer: .surfaceVertex,                              index: 3)
        computeEncoder.setBuffer(uniformBuffer,  layer: .surfaceEyeDirection,                        index: 4)
        computeEncoder.setBuffer(uniformBuffer,  layer: .surfaceNormal,                              index: 5)
        
        let numVertices = numSurfacesTimes256 + numSurfacesTimes256 >> 4
        computeEncoder.dispatchThreadgroups([ numVertices ], threadsPerThreadgroup: 1)
        
        computeEncoder.endEncoding()
        commandBuffer.commit()
    }
    
    enum GeometryType: CaseIterable {
        case opaque
        case transparent
    }
    
    func drawGeometry(type geometryType: GeometryType, renderEncoder: ARMetalRenderCommandEncoder) {
        assert(shouldRenderToDisplay)
        
        switch geometryType {
        case .opaque:
            guard opaqueAliases.count > 0 else { return }
        case .transparent:
            guard transparentAliases.count > 0 else { return }
        }
        
        debugLabel {
            let opacityString = geometryType == .opaque ? "Opaque" : "Transparent"
            renderEncoder.pushOptDebugGroup("Render AR \(opacityString) Interface Elements")
        }
        
        renderEncoder.setCullMode(.back)
        renderEncoder.setVertexBuffer(geometryBuffer, layer: .surfaceVertexAttribute, index: 1)
        
        
        
        var baseVertexUniformOffset   = self.vertexUniformOffset
        var baseFragmentUniformOffset = self.fragmentUniformOffset
        
        let vertexUniformStride = usingHeadsetMode ? MemoryLayout<HeadsetModeUniforms>.stride
                                                   : MemoryLayout<VertexUniforms>.stride
        
        var surfaceRenderPipelineState: ARMetalRenderPipelineState
        var startStencilReferenceValue: UInt32
        
        var elementGroupCounts: [Int]
        var elementAliases: [ARInterfaceElement.Alias]
        
        var baseMeshOffset: Int
        
        @inline(__always)
        func getGeometryOffsets(_ meshStart: Int) -> (Int, Int, Int) {
            if usingHeadsetMode {
                return (
                    meshStart * MemoryLayout<simd_float4>.stride,
                    meshStart * MemoryLayout<simd_float3>.stride,
                    meshStart * MemoryLayout<simd_half3>.stride >> 1
                )
            } else {
                return (
                    meshStart * MemoryLayout<simd_float4>.stride,
                    meshStart * MemoryLayout<simd_half3>.stride,
                    meshStart * MemoryLayout<simd_half3>.stride >> 1
                )
            }
        }
        
        switch geometryType {
        case .opaque:
            baseMeshOffset = 0
            startStencilReferenceValue = 0
            surfaceRenderPipelineState = self.surfaceRenderPipelineState
            
            renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceVertex,       index: 5)
            renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceEyeDirection, index: 6)
            renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceNormal,       index: 7)
            
            elementGroupCounts = opaqueElementGroupCounts
            elementAliases     = opaqueAliases
        case .transparent:
            baseMeshOffset = opaqueAliases.count
            baseVertexUniformOffset   += baseMeshOffset * vertexUniformStride
            baseFragmentUniformOffset += baseMeshOffset * MemoryLayout<FragmentUniforms>.stride
            
            renderEncoder.encoder.setDepthStencilState(depthPassDepthStencilState)
            renderEncoder.setRenderPipelineState(depthPassPipelineState)
            
            let meshStart = baseMeshOffset << 8 + baseMeshOffset << 4
            let (vertexOffset, eyeDirectionOffset, normalOffset) = getGeometryOffsets(meshStart)
            
            renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceVertex,       offset: vertexOffset,       index: 5)
            renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceEyeDirection, offset: eyeDirectionOffset, index: 6)
            renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceNormal,       offset: normalOffset,       index: 7)
            
            renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 266 * 6, indexType: .uint16,
                                                indexBuffer:       geometryBuffer.buffer,
                                                indexBufferOffset: geometryBuffer.offset(for: .surfaceIndex),
                                                instanceCount:     transparentAliases.count)
            
            
            
            startStencilReferenceValue = UInt32(baseMeshOffset)
            surfaceRenderPipelineState = transparentSurfaceRenderPipelineState
            
            if startStencilReferenceValue == 255 {
                startStencilReferenceValue = 1
            } else if startStencilReferenceValue > 0 {
                startStencilReferenceValue += 1
            }
            
            elementGroupCounts = transparentElementGroupCounts
            elementAliases     = transparentAliases
        }
        
        renderEncoder.setVertexBuffer  (uniformBuffer, layer: .vertexUniform,   offset: baseVertexUniformOffset,   index: 0)
        renderEncoder.setFragmentBuffer(uniformBuffer, layer: .fragmentUniform, offset: baseFragmentUniformOffset, index: 1)
        
        
        
        var numRenderedSurfaces = 0
        var numRenderedParagraphs = 0
        
        for groupCount in elementGroupCounts {
            if startStencilReferenceValue == 1 {
                renderEncoder.encoder.setDepthStencilState(clearStencilDepthStencilState)
                renderEncoder.setRenderPipelineState(clearStencilPipelineState)
                
                renderEncoder.encoder.setStencilReferenceValue(0)
                renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            } else if startStencilReferenceValue == 0 {
                startStencilReferenceValue = 1
            }
            
            // Render surfaces
            
            switch geometryType {
            case .opaque:
                renderEncoder.encoder.setDepthStencilState(surfaceDepthStencilState)
            case .transparent:
                renderEncoder.encoder.setDepthStencilState(transparentSurfaceDepthStencilState)
            }
            
            renderEncoder.setRenderPipelineState(surfaceRenderPipelineState)
            
            let endStencilReferenceValue = startStencilReferenceValue + UInt32(groupCount)
            var fragmentUniformOffset = baseFragmentUniformOffset
            
            for stencilReferenceValue in startStencilReferenceValue..<endStencilReferenceValue {
                renderEncoder.encoder.setStencilReferenceValue(stencilReferenceValue)
                
                if geometryType == .transparent {
                    let alpha = elementAliases[numRenderedSurfaces].surfaceOpacity
                    renderEncoder.encoder.setBlendColor(red: .nan, green: .nan, blue: .nan, alpha: alpha)
                }
                
                if numRenderedSurfaces > 0 {
                    let meshOffset = baseMeshOffset + numRenderedSurfaces
                    let meshStart = meshOffset << 8 + meshOffset << 4
                    let (vertexOffset, eyeOffset, normalOffset) = getGeometryOffsets(meshStart)
                    
                    renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceVertex,       offset: vertexOffset, index: 5, bound: true)
                    renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceEyeDirection, offset: eyeOffset,    index: 6, bound: true)
                    renderEncoder.setVertexBuffer(uniformBuffer, layer: .surfaceNormal,       offset: normalOffset, index: 7, bound: true)
                    
                    renderEncoder.setFragmentBuffer(uniformBuffer, layer: .fragmentUniform,
                                                    offset: fragmentUniformOffset, index: 1, bound: true)
                }
                
                renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 266 * 6, indexType: .uint16,
                                                    indexBuffer:       geometryBuffer.buffer,
                                                    indexBufferOffset: geometryBuffer.offset(for: .surfaceIndex))
                
                fragmentUniformOffset += MemoryLayout<FragmentUniforms>.stride
                numRenderedSurfaces   += 1
            }
            
            // Render text
            
            renderEncoder.encoder.setDepthStencilState(textDepthStencilState)
            renderEncoder.setRenderPipelineState(textRenderPipelineState)
            
            var vertexUniformOffset = baseVertexUniformOffset
            fragmentUniformOffset = baseFragmentUniformOffset
            
            var lastBoundFontID = -1
            
            for stencilReferenceValue in startStencilReferenceValue..<endStencilReferenceValue {
                let characterGroups = elementAliases[numRenderedParagraphs].characterGroups
                
                defer {
                    vertexUniformOffset   += vertexUniformStride
                    fragmentUniformOffset += MemoryLayout<FragmentUniforms>.stride
                    numRenderedParagraphs += 1
                }
                
                guard characterGroups.contains(where: { $0 != nil }) else { continue }
                
                if numRenderedParagraphs > 0 {
                    renderEncoder.setVertexBuffer(uniformBuffer, layer: .vertexUniform, offset: vertexUniformOffset,
                                                  index: 0, bound: true)
                }
                
                if stencilReferenceValue < endStencilReferenceValue || lastBoundFontID != -1 {
                    renderEncoder.encoder.setStencilReferenceValue(stencilReferenceValue)
                    
                    renderEncoder.setFragmentBuffer(uniformBuffer, layer: .fragmentUniform, offset: fragmentUniformOffset,
                                                    index: 1, bound: true)
                }
                
                for fontID in 0..<fontHandles.count {
                    guard let (boundingRects, glyphIndices) = characterGroups[fontID] else {
                        continue
                    }
                    
                    if lastBoundFontID != fontID {
                        renderEncoder.setVertexBuffer(fontHandles[fontID].texCoordBuffer, offset: 0, index: 2)
                        renderEncoder.setFragmentTexture(fontHandles[fontID].signedDistanceField, index: 0)

                        lastBoundFontID = fontID
                    }

                    var boundingRectPointer = boundingRects.withUnsafeBytes{ $0.baseAddress! }
                    var glyphIndexPointer   = glyphIndices .withUnsafeBytes{ $0.baseAddress! }
                    
                    var i = 0
                    let numCharacters = boundingRects.count
                    
                    while i < numCharacters {
                        let groupSize = min(numCharacters - i, 256)

                        let boundingRectBufferSize = groupSize * MemoryLayout<simd_float4>.stride
                        let glyphIndexBufferSize   = groupSize * MemoryLayout<UInt16>.stride

                        renderEncoder.setVertexBytes(boundingRectPointer, length: boundingRectBufferSize, index: 3)
                        renderEncoder.setVertexBytes(glyphIndexPointer,   length: glyphIndexBufferSize,   index: 4)
                        renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: 6, indexType: .uint16,
                                                            indexBuffer:       geometryBuffer.buffer,
                                                            indexBufferOffset: geometryBuffer.offset(for: .textIndex),
                                                            instanceCount: groupSize, baseVertex: 0, baseInstance: i)
                        
                        i += 256
                        boundingRectPointer += boundingRectBufferSize
                        glyphIndexPointer += glyphIndexBufferSize
                    }
                }
            }
            
            baseVertexUniformOffset   += 255 * vertexUniformStride
            baseFragmentUniformOffset += 255 * MemoryLayout<FragmentUniforms>.stride
            startStencilReferenceValue = 1
        }
        
        renderEncoder.popOptDebugGroup()
    }
    
}

extension InterfaceRenderer: BufferExpandable {
    
    enum BufferType: CaseIterable {
        case uniform
    }
    
    func ensureBufferCapacity(type: BufferType, capacity: Int) {
        let newCapacity = roundUpToPowerOf2(capacity)
        
        switch type {
        case .uniform: uniformBuffer.ensureCapacity(device: device, capacity: newCapacity)
        }
    }
    
}
#endif

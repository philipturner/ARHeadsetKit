//
//  CentralShapeContainerExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/19/21.
//

#if !os(macOS)
import Metal
import simd

extension CentralShapeContainer {
    
    mutating func clearAliases() {
        numAliases = 0
        
        for i in 0..<sizeRange.count {
            aliases[i].removeAll()
        }
    }
    
    mutating func ensureAliasCapacity() {
        let newCapacity = roundUpToPowerOf2(numAliases)
        uniformBuffer.ensureCapacity(device: device, capacity: newCapacity)
    }
    
    mutating func updateResources() {
        ensureAliasCapacity()
        
        let bufferElementOffset = renderIndex * uniformBuffer.capacity
        
        var fragmentUniformPointer = uniformBuffer[.fragment].assumingMemoryBound(to: FragmentUniforms.self)
        fragmentUniformPointer += bufferElementOffset
        
        let vertexUniformOffset = bufferElementOffset * MemoryLayout<HeadsetModeUniforms>.stride
        let rawVertexUniformPointer = uniformBuffer[.vertex] + vertexUniformOffset
        
        @inline(__always)
        func addUniforms<T: CentralVertexUniforms>(_ type: T.Type) {
            var vertexUniformPointer = rawVertexUniformPointer.assumingMemoryBound(to: T.self)
            
            aliases.forEach{ $0.forEach {
                vertexUniformPointer.pointee   = T(centralRenderer: centralRenderer, alias: $0)
                fragmentUniformPointer.pointee = FragmentUniforms(alias: $0)
                
                vertexUniformPointer   += 1
                fragmentUniformPointer += 1
            }}
        }
        
        if usingHeadsetMode {
            addUniforms(HeadsetModeUniforms.self)
        } else {
            addUniforms(VertexUniforms.self)
        }
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        guard numAliases > 0 else {
            return
        }
        
        if Self.shapeType == .cylinder {
            renderEncoder.setRenderPipelineState(centralRenderer.cylinderRenderPipelineState)
        } else if Self.shapeType == .cone {
            renderEncoder.setRenderPipelineState(centralRenderer.coneRenderPipelineState)
        } else if centralRenderer.didSetRenderPipeline[renderEncoder.threadID] == 0 {
            renderEncoder.setRenderPipelineState(centralRenderer.renderPipelineState)
        }
        
        if centralRenderer.didSetRenderPipeline[renderEncoder.threadID] == 0 {
            centralRenderer.didSetRenderPipeline[renderEncoder.threadID] = 1
        }
        
        renderEncoder.pushOptDebugGroup("Render \(String(Self.shapeType))s")
        
        let bufferElementOffset   = renderIndex * uniformBuffer.capacity
        var vertexUniformOffset   = bufferElementOffset * MemoryLayout<HeadsetModeUniforms>.stride
        var fragmentUniformOffset = bufferElementOffset * MemoryLayout<FragmentUniforms>.stride
        
        let normalOffset = self.normalOffset
        let indexOffset  = self.indexOffset
        
        let vertexUniformStride = usingHeadsetMode ? MemoryLayout<HeadsetModeUniforms>.stride
                                                   : MemoryLayout<VertexUniforms>.stride
        var alreadySetVertexBuffers = false
        var alreadySetUniforms = false
        
        for i in 0..<shapes.count {
            let numObjects = aliases[i].count
            if numObjects == 0 {
                continue
            }
            
            let shape = shapes[i]
            let fullVertexOffset = shape.normalOffset << 1
            let fullNormalOffset = shape.normalOffset + normalOffset
            
            if !alreadySetVertexBuffers {
                alreadySetVertexBuffers = true
                
                renderEncoder.setVertexBuffer(geometryBuffer, offset: fullVertexOffset, index: 0)
                renderEncoder.setVertexBuffer(geometryBuffer, offset: fullNormalOffset, index: 1)
            } else {
                renderEncoder.setVertexBufferOffset(fullVertexOffset, index: 0)
                renderEncoder.setVertexBufferOffset(fullNormalOffset, index: 1)
            }
            
            let fullIndexOffset = indexOffset + shape.indexOffset
            
            for j in 0..<2 {
                let subGroupSize = j == 0 ? aliases[i].closeAliases.count
                                          : aliases[i].farAliases.count
                if subGroupSize == 0 {
                    continue
                }
                
                renderEncoder.setVertexBuffer(uniformBuffer, layer: .vertex, offset: vertexUniformOffset,
                                              index: 2, bound: alreadySetUniforms)
                
                renderEncoder.setFragmentBuffer(uniformBuffer, layer: .fragment, offset: fragmentUniformOffset,
                                                index: 1, bound: alreadySetUniforms)
                
                alreadySetUniforms = true
                
                renderEncoder.setCullMode(j == 1 ? MTLCullMode.back : .none)
                
                renderEncoder.drawIndexedPrimitives(type: .triangle, indexCount: shape.numIndices, indexType: .uint16,
                                                    indexBuffer: geometryBuffer, indexBufferOffset: fullIndexOffset,
                                                    instanceCount: subGroupSize)
                
                vertexUniformOffset   += subGroupSize * vertexUniformStride
                fragmentUniformOffset += subGroupSize * MemoryLayout<FragmentUniforms>.stride
            }
        }
        
        renderEncoder.popOptDebugGroup()
    }
    
}
#endif

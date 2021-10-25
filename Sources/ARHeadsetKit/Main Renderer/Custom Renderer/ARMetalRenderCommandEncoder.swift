//
//  ARMetalRenderCommandEncoder.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 10/3/21.
//

#if !os(macOS)
import Metal

/// Provides a subset of the functionality of [`MTLRenderCommandEncoder`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder), to allow use of custom shaders for rendering in ARHeadsetKit.
public struct ARMetalRenderCommandEncoder {
    @usableFromInline var renderer: MainRenderer
    @usableFromInline var encoder: MTLRenderCommandEncoder
    @usableFromInline var threadID: Int
    
    #if DEBUG
    @usableFromInline class DebugLabelStack {
        @usableFromInline var depth: Int = 0
    }
    
    @usableFromInline var debugLabelStack = DebugLabelStack()
    #endif
    
    init(renderer: MainRenderer, encoder: MTLRenderCommandEncoder, threadID: Int) {
        self.renderer = renderer
        self.encoder  = encoder
        self.threadID = threadID
    }
}

// Resource bindings

public extension ARMetalRenderCommandEncoder {
    
    @inlinable @inline(__always)
    func pushOptDebugGroup(_ string: String) {
        #if DEBUG
        debugLabelStack.depth += 1
        encoder.pushDebugGroup(string)
        #endif
    }
    
    @inlinable @inline(__always)
    func popOptDebugGroup() {
        #if DEBUG
        encoder.popDebugGroup()
        debugLabelStack.depth -= 1
        #endif
    }
    
    @inline(__always)
    internal func clearDebugGroups() {
        #if DEBUG
        while debugLabelStack.depth > 0 {
            popOptDebugGroup()
        }
        #endif
    }
    
    /// See [setRenderPipelineState(_:)](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515811-setrenderpipelinestate).
    @inlinable @inline(__always)
    func setRenderPipelineState(_ pipelineState: ARMetalRenderPipelineState) {
        if renderer.usingHeadsetMode {
            encoder.setRenderPipelineState(pipelineState.headsetPipelineState)
        } else {
            encoder.setRenderPipelineState(pipelineState.handheldPipelineState)
        }
    }
    
    /// See [setCullMode(_:)](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515975-setcullmode). The cull mode is set to [`.back`](https://developer.apple.com/documentation/metal/mtlcullmode/back) by default, while in a `MTLRenderCommandEncoder`, it is [`.none`](https://developer.apple.com/documentation/metal/mtlcullmode/none) by default.
    @inlinable @inline(__always)
    func setCullMode(_ cullMode: MTLCullMode) {
        let centralRenderer = renderer.centralRenderer!
        
        if centralRenderer.currentlyCulling[threadID] != cullMode.rawValue {
            centralRenderer.currentlyCulling[threadID] = cullMode.rawValue
            encoder.setCullMode(cullMode)
        }
    }
    
}

// Vertex stage bindings

public extension ARMetalRenderCommandEncoder {
    
    /**
     See [`setVertexBuffer(_:offset:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515829-setvertexbuffer) and [`setVertexBufferOffset(_:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515433-setvertexbufferoffset).
     
     - Parameters:
        - index: Must be a number between 0 and 29, inclusive.
        - bound: Whether the `MTLLayeredBuffer` is already bound at the index passed into this function. Set this to `true` whenever possible to decrease this function's execution time.
     */
    @inlinable @inline(__always)
    func setVertexBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                                offset: Int = 0, index: Int, bound: Bool = false)
    {
        assert(index != 30, "Must not bind any buffer to the vertex stage at index 30!")
        encoder.setVertexBuffer(buffer, layer: layer, offset: offset, index: index, bound: bound)
    }
    
    /**
     See [`setVertexBytes(_:length:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515846-setvertexbytes).
     
     - Parameters:
        - index: Must be a number between 0 and 29, inclusive.
     */
    @inlinable @inline(__always)
    func setVertexBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
        assert(index != 30, "Must not bind any buffer to the vertex stage at index 30!")
        encoder.setVertexBytes(bytes, length: length, index: index)
    }
    
    /**
     See [`setVertexBuffer(_:offset:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515829-setvertexbuffer).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     
     - Parameters:
        - index: Must be a number between 0 and 29, inclusive.
     */
    @inlinable @inline(__always)
    func setVertexBuffer(_ buffer: MTLBuffer?, offset: Int, index: Int) {
        assert(index != 30, "Must not bind any buffer to the vertex stage at index 30!")
        encoder.setVertexBuffer(buffer, offset: offset, index: index)
    }
    
    /**
     See [`setVertexBufferOffset(_:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515433-setvertexbufferoffset).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     
     - Parameters:
        - index: Must be a number between 0 and 29, inclusive.
     */
    @inlinable @inline(__always)
    func setVertexBufferOffset(_ offset: Int, index: Int) {
        assert(index != 30, "Must not bind any buffer to the vertex stage at index 30!")
        encoder.setVertexBufferOffset(offset, index: index)
    }
    
    /// See [`setVertexSamplerState(_:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515537-setvertexsamplerstate).
    @inlinable @inline(__always)
    func setVertexSamplerState(_ sampler: MTLSamplerState?, index: Int) {
        encoder.setVertexSamplerState(sampler, index: index)
    }
    
    /// See [`setVertexSamplerState(_:lodMinClamp:lodMaxClamp:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515864-setvertexsamplerstate).
    @inlinable @inline(__always)
    func setVertexSamplerState(_ sampler: MTLSamplerState?, lodMinClamp: Float, lodMaxClamp: Float, index: Int) {
        encoder.setVertexSamplerState(sampler, lodMinClamp: lodMinClamp, lodMaxClamp: lodMaxClamp, index: index)
    }
    
    /// See [`setVertexTexture(_:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515842-setvertextexture).
    @inlinable @inline(__always)
    func setVertexTexture(_ texture: MTLTexture?, index: Int) {
        encoder.setVertexTexture(texture, index: index)
    }
    
}

// Fragment stage bindings

public extension ARMetalRenderCommandEncoder {
    
    /**
     See [`setFragmentBuffer(_:offset:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515470-setfragmentbuffer) and [`setFragmentBufferOffset(_:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515917-setfragmentbufferoffset).
     
     - Parameters:
        - index: Must be a number between 1 and 30, inclusive.
        - bound: Whether the `MTLLayeredBuffer` is already bound at the index passed into this function. Set this to `true` whenever possible to decrease this function's execution time.
     */
    @inlinable @inline(__always)
    func setFragmentBuffer<Layer: MTLBufferLayer>(_ buffer: MTLLayeredBuffer<Layer>, layer: Layer,
                                                  offset: Int = 0, index: Int, bound: Bool = false)
    {
        assert(index != 0, "Must not bind any buffer to the fragment stage at index 0!")
        encoder.setFragmentBuffer(buffer, layer: layer, offset: offset, index: index, bound: bound)
    }
    
    /**
     See [`setFragmentBytes(_:length:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1516192-setfragmentbytes).
     
     - Parameters:
        - index: Must be a number between 1 and 30, inclusive.
     */
    @inlinable @inline(__always)
    func setFragmentBytes(_ bytes: UnsafeRawPointer, length: Int, index: Int) {
        assert(index != 0, "Must not bind any buffer to the fragment stage at index 0!")
        encoder.setFragmentBytes(bytes, length: length, index: index)
    }
    
    /**
     See [`setFragmentBuffer(_:offset:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515470-setfragmentbuffer).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     
     - Parameters:
        - index: Must be a number between 1 and 30, inclusive.
     */
    @inlinable @inline(__always)
    func setFragmentBuffer(_ buffer: MTLBuffer?, offset: Int, index: Int) {
        assert(index != 0, "Must not bind any buffer to the fragment stage at index 0!")
        encoder.setFragmentBuffer(buffer, offset: offset, index: index)
    }
    
    /**
     See [`setFragmentBufferOffset(_:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515917-setfragmentbufferoffset).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     
     - Parameters:
        - index: Must be a number between 1 and 30, inclusive.
     */
    @inlinable @inline(__always)
    func setFragmentBufferOffset(_ offset: Int, index: Int) {
        assert(index != 0, "Must not bind any buffer to the fragment stage at index 0!")
        encoder.setFragmentBufferOffset(offset, index: index)
    }
    
    /// See [`setFragmentSamplerState(_:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515577-setfragmentsamplerstate).
    @inlinable @inline(__always)
    func setFragmentSamplerState(_ sampler: MTLSamplerState?, index: Int) {
        encoder.setFragmentSamplerState(sampler, index: index)
    }
    
    /// See [`setFragmentSamplerState(_:lodMinClamp:lodMaxClamp:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515485-setfragmentsamplerstate).
    @inlinable @inline(__always)
    func setFragmentSamplerState(_ sampler: MTLSamplerState?, lodMinClamp: Float, lodMaxClamp: Float, index: Int) {
        encoder.setFragmentSamplerState(sampler, lodMinClamp: lodMinClamp, lodMaxClamp: lodMaxClamp, index: index)
    }
    
    /// See [`setFragmentTexture(_:index:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515390-setfragmenttexture).
    @inlinable @inline(__always)
    func setFragmentTexture(_ texture: MTLTexture?, index: Int) {
        encoder.setFragmentTexture(texture, index: index)
    }
    
}

// Draw commands

public extension ARMetalRenderCommandEncoder {
    
    /// See [`drawPrimitives(type:vertexStart:vertexCount:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1516326-drawprimitives).
    @inlinable @inline(__always)
    func drawPrimitives(type primitiveType: MTLPrimitiveType, vertexStart: Int, vertexCount: Int) {
        encoder.drawPrimitives(type: primitiveType, vertexStart: vertexStart, vertexCount: vertexCount)
    }
    
    /// See [drawPrimitives(type:vertexStart:vertexCount:instanceCount:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515327-drawprimitives).
    @inlinable @inline(__always)
    func drawPrimitives(type primitiveType: MTLPrimitiveType, vertexStart: Int, vertexCount: Int, instanceCount: Int) {
        encoder.drawPrimitives(type: primitiveType, vertexStart: vertexStart, vertexCount: vertexCount, instanceCount: instanceCount)
    }
    
    /// See [`drawPrimitives(type:vertexStart:vertexCount:instanceCount:baseInstance:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515561-drawprimitives).
    @inlinable @inline(__always)
    func drawPrimitives(type primitiveType: MTLPrimitiveType, vertexStart:  Int, vertexCount: Int,
                        instanceCount:      Int,              baseInstance: Int)
    {
        encoder.drawPrimitives(type:          primitiveType, vertexStart:  vertexStart, vertexCount: vertexCount,
                               instanceCount: instanceCount, baseInstance: baseInstance)
    }
    
    // Commands with MTLLayeredBuffer
    
    /// See [`drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515542-drawindexedprimitives).
    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer: MTLBufferLayer>(
        type:        MTLPrimitiveType,        indexCount:       Int,   indexType:        MTLIndexType,
        indexBuffer: MTLLayeredBuffer<Layer>, indexBufferLayer: Layer, indexLayerOffset: Int = 0)
    {
        let internalOffset = indexBuffer.offset(for: indexBufferLayer) + indexLayerOffset
        encoder.drawIndexedPrimitives(type:        type,               indexCount: indexCount, indexType: indexType,
                                      indexBuffer: indexBuffer.buffer, indexBufferOffset: internalOffset)
    }
    
    /// See [`drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515699-drawindexedprimitives).
    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer: MTLBufferLayer>(
        type:          MTLPrimitiveType,        indexCount:       Int,   indexType:        MTLIndexType,
        indexBuffer:   MTLLayeredBuffer<Layer>, indexBufferLayer: Layer, indexLayerOffset: Int = 0,
        instanceCount: Int)
    {
        let internalOffset = indexBuffer.offset(for: indexBufferLayer) + indexLayerOffset
        encoder.drawIndexedPrimitives(type:          type,               indexCount: indexCount, indexType: indexType,
                                      indexBuffer:   indexBuffer.buffer, indexBufferOffset: internalOffset,
                                      instanceCount: instanceCount)
    }
    
    /// See [`drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:baseVertex:baseInstance:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515520-drawindexedprimitives).
    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer: MTLBufferLayer>(
        type:          MTLPrimitiveType,        indexCount:       Int,   indexType:        MTLIndexType,
        indexBuffer:   MTLLayeredBuffer<Layer>, indexBufferLayer: Layer, indexLayerOffset: Int = 0,
        instanceCount: Int,                     baseVertex:       Int,   baseInstance:     Int)
    {
        let internalOffset = indexBuffer.offset(for: indexBufferLayer) + indexLayerOffset
        encoder.drawIndexedPrimitives(type:          type,               indexCount: indexCount, indexType: indexType,
                                      indexBuffer:   indexBuffer.buffer, indexBufferOffset: internalOffset,
                                      instanceCount: instanceCount,      baseVertex: baseVertex, baseInstance: baseInstance)
    }
    
    // Commands with MTLBuffer
    
    /**
     See [`drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515542-drawindexedprimitives).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     */
    @inlinable @inline(__always)
    func drawIndexedPrimitives(type: MTLPrimitiveType, indexCount: Int, indexType: MTLIndexType,
                               indexBuffer: MTLBuffer, indexBufferOffset: Int)
    {
        encoder.drawIndexedPrimitives(type: type, indexCount: indexCount, indexType: indexType,
                                      indexBuffer: indexBuffer, indexBufferOffset: indexBufferOffset)
    }
    
    /**
     See [`drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515699-drawindexedprimitives).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     */
    @inlinable @inline(__always)
    func drawIndexedPrimitives(type: MTLPrimitiveType, indexCount: Int, indexType: MTLIndexType,
                               indexBuffer: MTLBuffer, indexBufferOffset: Int, instanceCount: Int)
    {
        encoder.drawIndexedPrimitives(type:          type,        indexCount: indexCount, indexType: indexType,
                                      indexBuffer:   indexBuffer, indexBufferOffset: indexBufferOffset,
                                      instanceCount: instanceCount)
    }
    
    /**
     See [`drawIndexedPrimitives(type:indexCount:indexType:indexBuffer:indexBufferOffset:instanceCount:baseVertex:baseInstance:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515520-drawindexedprimitives).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     */
    @inlinable @inline(__always)
    func drawIndexedPrimitives(type: MTLPrimitiveType, indexCount: Int, indexType: MTLIndexType,
                               indexBuffer: MTLBuffer, indexBufferOffset: Int,
                               instanceCount:     Int, baseVertex: Int, baseInstance: Int)
    {
        encoder.drawIndexedPrimitives(type:          type,          indexCount: indexCount, indexType: indexType,
                                      indexBuffer:   indexBuffer,   indexBufferOffset: indexBufferOffset,
                                      instanceCount: instanceCount, baseVertex: baseVertex, baseInstance: baseInstance)
    }
    
}

// Indirect draw commands

public extension ARMetalRenderCommandEncoder {
    
    // Commands with MTLLayeredBuffer
    
    /// See [`drawPrimitives(type:indirectBuffer:indirectBufferOffset:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515467-drawprimitives).
    @inlinable @inline(__always)
    func drawPrimitives<Layer: MTLBufferLayer>(type:     MTLPrimitiveType, indirectBuffer: MTLLayeredBuffer<Layer>,
                                               indirectBufferLayer: Layer, indirectLayerOffset: Int = 0)
    {
        let internalOffset = indirectBuffer.offset(for: indirectBufferLayer) + indirectLayerOffset
        encoder.drawPrimitives(type: type, indirectBuffer: indirectBuffer.buffer, indirectBufferOffset: internalOffset)
    }
    
    /// See [`drawIndexedPrimitives(type:indexType:indexBuffer:indexBufferOffset:indirectBuffer:indirectBufferOffset:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515392-drawindexedprimitives).
    @inlinable @inline(__always)
    func drawIndexedPrimitives<Layer1: MTLBufferLayer, Layer2: MTLBufferLayer>(
        type:           MTLPrimitiveType,         indexType:           MTLIndexType,
        indexBuffer:    MTLLayeredBuffer<Layer1>, indexBufferLayer:    Layer1, indexLayerOffset:    Int = 0,
        indirectBuffer: MTLLayeredBuffer<Layer2>, indirectBufferLayer: Layer2, indirectLayerOffset: Int = 0)
    {
        let internalOffset1 = indexBuffer   .offset(for: indexBufferLayer)    + indexLayerOffset
        let internalOffset2 = indirectBuffer.offset(for: indirectBufferLayer) + indirectLayerOffset
        
        encoder.drawIndexedPrimitives(type:           type,                  indexType:            indexType,
                                      indexBuffer:    indexBuffer.buffer,    indexBufferOffset:    internalOffset1,
                                      indirectBuffer: indirectBuffer.buffer, indirectBufferOffset: internalOffset2)
    }
    
    // Commands with MTLBuffer
    
    /**
     See [`drawPrimitives(type:indirectBuffer:indirectBufferOffset:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515467-drawprimitives).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     */
    @inlinable @inline(__always)
    func drawPrimitives(type: MTLPrimitiveType, indirectBuffer: MTLBuffer, indirectBufferOffset: Int) {
        encoder.drawPrimitives(type: type, indirectBuffer: indirectBuffer, indirectBufferOffset: indirectBufferOffset)
    }
    
    /**
     See [`drawIndexedPrimitives(type:indexType:indexBuffer:indexBufferOffset:indirectBuffer:indirectBufferOffset:)`](https://developer.apple.com/documentation/metal/mtlrendercommandencoder/1515392-drawindexedprimitives).
     
     Bind a ``MTLLayeredBuffer`` instead whenever possible.
     */
    @inlinable @inline(__always)
    func drawIndexedPrimitives(type:    MTLPrimitiveType, indexType:   MTLIndexType,
                               indexBuffer:    MTLBuffer, indexBufferOffset:    Int,
                               indirectBuffer: MTLBuffer, indirectBufferOffset: Int)
    {
        encoder.drawIndexedPrimitives(type:           type,           indexType:            indexType,
                                      indexBuffer:    indexBuffer,    indexBufferOffset:    indexBufferOffset,
                                      indirectBuffer: indirectBuffer, indirectBufferOffset: indirectBufferOffset)
    }
}
#endif

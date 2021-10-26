//
//  CustomRenderer.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 10/2/21.
//

#if !os(macOS)
import Metal
import simd

public protocol CustomRenderer: DelegateRenderer {
    init(renderer: MainRenderer, library: MTLLibrary!)
    
    /**
     Update resources, render AR objects, and any dispatch pre-render compute command buffers here.
     */
    func updateResources()
    /**
     Renders geometry to the screen using custom shaders.
     
     This may not include transparency unless transparent pixels are always either 0% or 100% opaque, and 0% opaque pixels never modify the depth buffer.
     
     > Warning: This may be called twice per frame in headset mode, from separate threads. Do not modify your custom renderer's stored variables in this function.
     */
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder)
}
#endif

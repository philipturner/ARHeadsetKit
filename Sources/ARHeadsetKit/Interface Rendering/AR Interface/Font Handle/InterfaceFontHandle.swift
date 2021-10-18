//
//  InterfaceFontHandle.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/29/21.
//

import Metal
import simd
import SwiftUI
import Compression

extension InterfaceRenderer {
    
    struct FontHandle {
        var attributes: [NSAttributedString.Key : Any]
        var glyphMap: [UInt16]
        var boundingRects: [simd_float4]
        
        var texCoordBuffer: MTLBuffer
        var signedDistanceField: MTLTexture
        
        init(device: MTLDevice, commandQueue: MTLCommandQueue,
             _ prepareBitmapPipelineState: MTLComputePipelineState! = nil,
             _ prepareMipmapLevelsPipelineState: MTLComputePipelineState! = nil,
             _ createSignedDistanceFieldPipelineState: MTLComputePipelineState! = nil,
             
             name: String, size: CGFloat,
             compressedData: Data! = nil, uncompressedDataSize: Int! = nil,
             returnSemaphore: DispatchSemaphore! = nil,
             commandBuffer: UnsafeMutablePointer<MTLCommandBuffer?>! = nil)
        {
            let doubleSize = size + size
            var ctFont = CTFont?(CTFontDescriptor?(name, doubleSize)!, doubleSize, nil)!
            
            // 0x21BA - counterclockwise open circle arrow
            // 0x21BB - clockwise open circle arrow
            
            var characters = (33..<127).map{ UniChar($0) } + [0x21BA, 0x21BB]
            var glyphs = [CGGlyph](repeating: .max, count: characters.count)
            _ = ctFont.getGlyphs(&characters, &glyphs, characters.count)
            
            glyphMap = Array(repeating: 65535, count: Int(glyphs.max()! + 1))
            for i in 0..<characters.count { glyphMap[Int(glyphs[i])] = UInt16(i) }
            
            var boundingRects = [CGRect](repeating: .null, count: characters.count)
            _ = ctFont.getBoundingRects(.horizontal, &glyphs, &boundingRects, characters.count)
            var positionTransforms = [CGAffineTransform](capacity: characters.count)
            
            let exclamationIndex = characters.firstIndex(of: Character("!").utf16.first!)!
            let strokeWidth = ceil(boundingRects[exclamationIndex].width)
            let marginMultipliers = fma(Double(strokeWidth), .init(1, 0.5), .init(2, 1))
            let margin     = CGFloat(marginMultipliers[0])
            let marginHalf = CGFloat(marginMultipliers[1])
            
            // Position glyphs within texture
            
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var maxHeight: CGFloat = 0
            
            for boundingRect in boundingRects {
                var previousX = currentX
                let footprintX = margin + boundingRect.width
                guard footprintX > margin else {
                    positionTransforms.append(.identity)
                    continue
                }
                
                let footprintY = margin + boundingRect.height
                currentX += footprintX
                
                if currentX > 8192 {
                    previousX = 0
                    currentX = footprintX
                    currentY += maxHeight
                    maxHeight = footprintY
                } else {
                    maxHeight = max(footprintY, maxHeight)
                }
                
                let positionTransformX = previousX + marginHalf - boundingRect.origin.x
                let positionTransformY = currentY  + marginHalf - boundingRect.origin.y
                
                positionTransforms.append(CGAffineTransform(translationX: positionTransformX,
                                                                       y: positionTransformY))
            }
            
            // Create signed distance field
            
            let textureHeightHalf = (Int(ceil(currentY + maxHeight)) + 1) >> 1
            var commandBufferToWaitOn: MTLCommandBuffer?
            
            if let compressedData = compressedData {
                let uncompressedDataPointer = malloc(uncompressedDataSize).assumingMemoryBound(to: UInt8.self)
                let compressedDataPointer   = compressedData.withUnsafeBytes{ $0.baseAddress! }.assumingMemoryBound(to: UInt8.self)
                
                compression_decode_buffer(uncompressedDataPointer, uncompressedDataSize,
                                          compressedDataPointer,   uncompressedDataSize, nil, COMPRESSION_LZ4)
                
                let textureDescriptor = MTLTextureDescriptor()
                textureDescriptor.width  = 4096
                textureDescriptor.height = textureHeightHalf
                textureDescriptor.storageMode = .shared
                textureDescriptor.pixelFormat = .r16Unorm
                textureDescriptor.usage = .shaderRead
                
                signedDistanceField = device.makeTexture(descriptor: textureDescriptor)!
                debugLabel { [signedDistanceField] in
                    signedDistanceField.label = "\(name) \(size) Signed Distance Field"
                }
                
                signedDistanceField.replace(region: MTLRegionMake2D(0, 0, 4096, textureHeightHalf), mipmapLevel: 0, slice: 0,
                                            withBytes: uncompressedDataPointer, bytesPerRow: 4096 * MemoryLayout<UInt16>.stride,
                                            bytesPerImage: uncompressedDataSize)
                free(uncompressedDataPointer)
                
                let commandBuffer = commandQueue.makeDebugCommandBuffer()
                commandBuffer.optLabel = "Signed Distance Field Loading Command Buffer"
                
                let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
                blitEncoder.optLabel = "Signed Distance Field Loading - Compress Texture"
                
                blitEncoder.optimizeContentsForGPUAccess(texture: signedDistanceField)
                blitEncoder.endEncoding()
                
                commandBuffer.commit()
                commandBufferToWaitOn = commandBuffer
            } else {
                let results = createSignedDistanceField(device: device, commandQueue: commandQueue,
                                                        prepareBitmapPipelineState,
                                                        prepareMipmapLevelsPipelineState,
                                                        createSignedDistanceFieldPipelineState,
                                                        
                                                        font: ctFont, glyphs: glyphs, positionTransforms: positionTransforms,
                                                        textureHeight: textureHeightHalf << 1, radius: strokeWidth * 0.5,
                                                        returnSemaphore: returnSemaphore)
                
                (signedDistanceField, commandBuffer.pointee) = results
            }
            
            // Prepare for rendering the font
            
            let fontDescriptor = UIFontDescriptor(name: name, size: size)
            attributes = [.font : UIFont(descriptor: fontDescriptor, size: size)]
            
            ctFont = CTFont?(CTFontDescriptor?(name, size)!, size, nil)!
            
            var newBoundingRects = [CGRect](repeating: .null, count: characters.count)
            _ = ctFont.getBoundingRects(.horizontal, &glyphs, &newBoundingRects, boundingRects.count)
            
            
            
            let texCoordBufferSize = boundingRects.count * MemoryLayout<simd_float4>.stride
            texCoordBuffer = device.makeBuffer(length: texCoordBufferSize, options: [.cpuCacheModeWriteCombined, .storageModeShared])!
            debugLabel { [texCoordBuffer] in
                texCoordBuffer.label = "\(name) \(size) Texture Coordinate Buffer"
            }
            
            let texCoordPointer = texCoordBuffer.contents().assumingMemoryBound(to: simd_float4.self)
            self.boundingRects = Array(unsafeUninitializedCount: boundingRects.count)
            
            for i in 0..<boundingRects.count {
                let newBoundingRect = newBoundingRects[i]
                let oldBoundingRect = boundingRects[i]
                
                let newBoundingRectSize = simd_float2(.init(newBoundingRect.width), .init(newBoundingRect.height))
                let oldBoundingRectSize = simd_float2(.init(oldBoundingRect.width), .init(oldBoundingRect.height))
                
                let offset = simd_float2(.init(newBoundingRect.origin.x), .init(newBoundingRect.origin.y))
                let origin = simd_float2(.init(oldBoundingRect.origin.x + positionTransforms[i].tx),
                                         .init(oldBoundingRect.origin.y + positionTransforms[i].ty))
                
                self.boundingRects[i] = .init(lowHalf: offset, highHalf: offset + newBoundingRectSize)
                texCoordPointer   [i] = .init(lowHalf: origin, highHalf: origin + oldBoundingRectSize) * 0.5
            }
            
            commandBufferToWaitOn?.waitUntilCompleted()
        }
    }
    
}

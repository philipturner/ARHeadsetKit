//
//  InterfaceFontCreation.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/29/21.
//

#if !os(macOS)
import Metal
import simd
import CoreText
import Compression

// This algorithm creates a highly accurate signed distance field by finding the
// closest distance to an edge between neighboring inside/outside pixels, rather than
// the distance to the center of the closest pixel with a different inside-ness.
//
// By traversing a 2D area hierarchy, each pixel quickly estimates its distance
// to a nearby edge, if one exists within the search radius. If an edge does exist,
// then it finds the pixel with the closest edge at the lowest layer of the hierarchy.
//
// This has an algorithmic complexity somewhere between O(n^3) and O(n^2 log(n)),
// while a brute force approach has O(n^4) complexity (where `n` is font size).

extension InterfaceRenderer {
    
    static func createFontHandles(device: MTLDevice, commandQueue: MTLCommandQueue, library: MTLLibrary,
                                  configurations: [(name: String, size: CGFloat)]) -> [FontHandle]
    {
        var output = [FontHandle?](repeating: nil, count: configurations.count)
        let returnSemaphore = DispatchSemaphore(value: 2)
        
        var prepareBitmapPipelineState: MTLComputePipelineState!
        var prepareMipmapLevelsPipelineState: MTLComputePipelineState!
        var createSignedDistanceFieldPipelineState: MTLComputePipelineState!
        
        for i in 0..<configurations.count {
            returnSemaphore.wait()
            let configuration = configurations[i]
            
            if let (compressedData, uncompressedDataSize) = readSignedDistanceFieldData(fontName: configuration.name,
                                                                                        fontSize: configuration.size) {
                DispatchQueue.global(qos: .background).async {
                    output[i] = FontHandle(device: device, commandQueue: commandQueue,

                                           name: configuration.name, size: configuration.size,
                                           compressedData: compressedData, uncompressedDataSize: uncompressedDataSize)
                    returnSemaphore.signal()
                }
            } else {
                if prepareBitmapPipelineState == nil {
                    let computePipelineDescriptor = MTLComputePipelineDescriptor()
                    computePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = true
                    
                    computePipelineDescriptor.computeFunction = library.makeFunction(name: "createTextSignedDistanceField")!
                    computePipelineDescriptor.optLabel = "Create Text Signed Distance Field"
                    createSignedDistanceFieldPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
                    
                    computePipelineDescriptor.computeFunction = library.makeFunction(name: "prepareTextBitmap")!
                    computePipelineDescriptor.optLabel = "Prepare Text Bitmap Pipeline"
                    prepareBitmapPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
                    
                    if !device.supportsFamily(.apple4) {
                        computePipelineDescriptor.threadGroupSizeIsMultipleOfThreadExecutionWidth = false
                    }
                    
                    computePipelineDescriptor.computeFunction = library.makeFunction(name: "prepareTextMipmapLevels")!
                    computePipelineDescriptor.optLabel = "Prepare Text Mipmap Levels"
                    prepareMipmapLevelsPipelineState = device.makeComputePipelineState(descriptor: computePipelineDescriptor)
                }
                
                DispatchQueue.global(qos: .userInitiated).async {
                    var commandBuffer: MTLCommandBuffer!
                    
                    output[i] = FontHandle(device: device, commandQueue: commandQueue,
                                           prepareBitmapPipelineState,
                                           prepareMipmapLevelsPipelineState,
                                           createSignedDistanceFieldPipelineState,
                                           
                                           name: configuration.name, size: configuration.size,
                                           returnSemaphore: returnSemaphore, commandBuffer: &commandBuffer)
                    
                    commandBuffer.commit()
                }
            }
            
        }
        
        returnSemaphore.wait()
        returnSemaphore.wait()
        
        returnSemaphore.signal()
        returnSemaphore.signal()
        
        return output.map{ $0! }
    }
    
    static func createSignedDistanceField(device: MTLDevice, commandQueue: MTLCommandQueue,
                                          _ prepareBitmapPipelineState: MTLComputePipelineState,
                                          _ prepareMipmapLevelsPipelineState: MTLComputePipelineState,
                                          _ createSignedDistanceFieldPipelineState: MTLComputePipelineState,
                                          
                                          font: CTFont, glyphs: [CGGlyph], positionTransforms: [CGAffineTransform],
                                          textureHeight: Int, radius: CGFloat,
                                          returnSemaphore: DispatchSemaphore) -> (MTLTexture, MTLCommandBuffer)
    {
        let buffer = device.makeBuffer(length: (textureHeight << 13) + 100_000, options: [.cpuCacheModeWriteCombined, .storageModeShared])!
        buffer.optLabel = "Signed Distance Field Generation Search Parameter Buffer"
        
        let commandEncodingSemaphore = DispatchSemaphore(value: 0)
        
        var signedDistanceField: MTLTexture!
        var commandBuffer: MTLCommandBuffer!
        
        func createBitmap() {
            let context = CGContext(data: buffer.contents(),
                                    width: 8192,
                                    height: textureHeight,
                                    bitsPerComponent: 8,
                                    bytesPerRow: 8192,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGBitmapInfo.alphaInfoMask.rawValue & CGImageAlphaInfo.none.rawValue)!
            
            context.setAllowsAntialiasing(false)
            context.translateBy(x: 0, y: .init(textureHeight))
            context.scaleBy(x: 1, y: -1)
            
            context.setFillColor(gray: 0, alpha: 1)
            context.fill(.init(x: 0, y: 0, width: 8192, height: textureHeight))
            
            context.setFillColor(gray: 1, alpha: 1)
            
            for i in 0..<glyphs.count {
                var positionTransformCopy = positionTransforms[i]
                
                if let path = font.createPath(glyphs[i], &positionTransformCopy) {
                    context.addPath(path)
                    context.fillPath()
                }
            }
            
            commandEncodingSemaphore.wait()
        }
        
        DispatchQueue.global(qos: .default).async { [self] in
            let radius_int = Int(ceil(radius))
            
            let baseLevel = createSignedDistanceFieldParameters(radius: radius_int)
            var upperLevels = [[(simd_ushort2, Float)]](capacity: 8)
            var numUpperLevels = 0
            
            while true {
                numUpperLevels += 1
                let nextLevel = createSignedDistanceFieldMipmapParameters(level: numUpperLevels,
                                                                          fullResolutionRadius: radius_int)
                
                upperLevels.append(nextLevel)
                if nextLevel.count <= 2 { break }
            }
            
            var upperLevelOffset: Int
            var upperLevelOffsetOffset: Int
            var levelSizeOffset: Int
            var maxDistanceAndHalfInverseOffset: Int
            
            
            
            let baseLevelSize = baseLevel.count
            let baseLevelNumBytes = baseLevelSize * MemoryLayout<simd_float2>.stride
            let baseLevelOffset = textureHeight << 13
            upperLevelOffset = baseLevelOffset + baseLevelNumBytes
            
            var levelSizes = [UInt16](unsafeUninitializedCapacity: numUpperLevels + 1) { pointer, count in
                count = 1
                pointer[0] = UInt16(baseLevelSize)
            }
            
            let bufferPointer = buffer.contents()
            memcpy(bufferPointer + baseLevelOffset, baseLevel.withUnsafeBytes{ $0.baseAddress! }, baseLevelNumBytes)
            
            var currentOffset = 0
            var previousLevel = baseLevel
            var upperLevelPointer = (bufferPointer + upperLevelOffset).assumingMemoryBound(to: simd_ushort3.self)
            
            var upperLevelOffsets = [UInt16](capacity: numUpperLevels)
            
            for i in 0..<numUpperLevels {
                upperLevelOffsets.append(UInt16(currentOffset))
                
                let currentLevel = upperLevels[i]
                let currentLevelSize = currentLevel.count
                currentOffset += currentLevelSize
                levelSizes.append(UInt16(currentLevelSize))
                
                let maxComparisonIndex = previousLevel.count
                var currentComparisonIndex = 0
                
                currentLevel.forEach { parameters in
                    while currentComparisonIndex < maxComparisonIndex,
                          previousLevel[currentComparisonIndex    ].1 != parameters.1,
                          previousLevel[currentComparisonIndex + 1].1 <= parameters.1
                    {
                        currentComparisonIndex += 1
                    }
                    
                    upperLevelPointer.pointee = .init(parameters.0, UInt16(currentComparisonIndex))
                    upperLevelPointer += 1
                }
                
                previousLevel = currentLevel
            }
            
            
            
            let upperLevelsNumBytes  = currentOffset * MemoryLayout<simd_ushort3>.stride
            let upperLevelOffsetsNumBytes = ~3 & (numUpperLevels * MemoryLayout<UInt16>.stride + 3)
            let levelSizesNumBytes        = (numUpperLevels + 1) * MemoryLayout<UInt16>.stride
            
            upperLevelOffsetOffset          = upperLevelOffset       + upperLevelsNumBytes
            levelSizeOffset                 = upperLevelOffsetOffset + upperLevelOffsetsNumBytes
            maxDistanceAndHalfInverseOffset = levelSizeOffset        + levelSizesNumBytes
            maxDistanceAndHalfInverseOffset = ~7 & (maxDistanceAndHalfInverseOffset + 7)
            
            let upperLevelOffsetPointer = (bufferPointer + upperLevelOffsetOffset).assumingMemoryBound(to: UInt16.self)
            let levelSizePointer        = (bufferPointer + levelSizeOffset).assumingMemoryBound(to: UInt16.self)
            
            for i in 0..<numUpperLevels { upperLevelOffsetPointer[i] = upperLevelOffsets[i] }
            for i in 0..<numUpperLevels + 1 { levelSizePointer[i] = levelSizes[i] }
            
            let maxDistanceAndHalfInversePointer = bufferPointer + maxDistanceAndHalfInverseOffset
            maxDistanceAndHalfInversePointer.assumingMemoryBound(to: simd_float2.self)[0] = .init(Float(radius), 0.5 / Float(radius))
            
            
            
            let textureDescriptor = MTLTextureDescriptor()
            textureDescriptor.storageMode = .shared
            textureDescriptor.pixelFormat = .r8Uint
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            
            textureDescriptor.height = textureHeight >> 1
            textureDescriptor.width  = 4096
            textureDescriptor.mipmapLevelCount = numUpperLevels
            let mipmapLevels = device.makeTexture(descriptor: textureDescriptor)!
            mipmapLevels.optLabel = "Glyph Mipmap Levels"
            
            textureDescriptor.pixelFormat = .r16Unorm
            textureDescriptor.usage = .shaderRead
            textureDescriptor.mipmapLevelCount = 1
            signedDistanceField = device.makeTexture(descriptor: textureDescriptor)
            debugLabel { signedDistanceField.label = "\(font.fullName) \(font.size * 0.5) Signed Distance Field" }
            
            textureDescriptor.usage = [.shaderRead, .shaderWrite]
            textureDescriptor.height = textureHeight
            textureDescriptor.width = 8192
            textureDescriptor.mipmapLevelCount = 2
            let uncompressedSignedDistanceField = device.makeTexture(descriptor: textureDescriptor)!
            uncompressedSignedDistanceField.optLabel = "Original Text Signed Distance Field"
            
            textureDescriptor.resourceOptions = buffer.resourceOptions
            textureDescriptor.pixelFormat = .r8Uint
            textureDescriptor.mipmapLevelCount = 1
            let bitmap = buffer.makeTexture(descriptor: textureDescriptor, offset: 0, bytesPerRow: 8192)!
            bitmap.optLabel = "Glyph Bitmap"
            
            
            
            commandBuffer = commandQueue.makeDebugCommandBuffer()
            commandBuffer.optLabel = "Signed Distance Field Creation Command Buffer"
            commandBuffer.addCompletedHandler { commandBuffer in
                DispatchQueue.global(qos: .background).async {
                    let uncompressedDataSize = textureHeight * 4096 >> 1 * MemoryLayout<UInt16>.stride
                    let uncompressedDataPointer = malloc(uncompressedDataSize)!.assumingMemoryBound(to: UInt8.self)
                    let compressedDataPointer   = malloc(uncompressedDataSize)!.assumingMemoryBound(to: UInt8.self)
                    
                    uncompressedSignedDistanceField.getBytes(uncompressedDataPointer, bytesPerRow: 4096 * MemoryLayout<UInt16>.stride,
                                                             from: MTLRegionMake2D(0, 0, 4096, textureHeight >> 1), mipmapLevel: 1)
                    
                    let compressedDataSize = compression_encode_buffer(compressedDataPointer,   uncompressedDataSize,
                                                                       uncompressedDataPointer, uncompressedDataSize, nil, COMPRESSION_LZ4)
                    
                    let compressedData = Data(bytesNoCopy: compressedDataPointer, count: compressedDataSize, deallocator: .free)
                    
                    writeSignedDistanceFieldData(fontName: font.fullName, fontSize: font.size * 0.5,
                                                 compressedData: compressedData, uncompressedDataSize: uncompressedDataSize)
                    returnSemaphore.signal()
                }
            }
            
            let computeEncoder = commandBuffer.makeComputeCommandEncoder()!
            computeEncoder.optLabel = "Signed Distance Field Creation - Compute Pass"
            
            computeEncoder.setComputePipelineState(prepareBitmapPipelineState)
            computeEncoder.setTexture(bitmap,       index: 0)
            computeEncoder.setTexture(mipmapLevels, index: 1)
            
            let usingThreadgroups = device.supportsFamily(.apple4)
            let textureHeightHalf = textureHeight >> 1
            
            if usingThreadgroups {
                computeEncoder.dispatchThreads([ 4096, textureHeightHalf ], threadsPerThreadgroup: [ 16, min(textureHeightHalf, 16) ])
            } else {
                computeEncoder.dispatchThreadgroups([ 4096 / 256, textureHeightHalf ], threadsPerThreadgroup: 256)
            }
            
            
            
            computeEncoder.setComputePipelineState(prepareMipmapLevelsPipelineState)
            computeEncoder.setTexture(mipmapLevels, index: 2)
            
            let dispatchWidth = 4096 >> numUpperLevels
            let dispatchHeight = (textureHeight - 1) >> (numUpperLevels + 1) + 1
            
            if usingThreadgroups {
                let threadgroupSize: MTLSize = [ min(dispatchWidth, 64), min(dispatchHeight, 4) ]
                computeEncoder.dispatchThreads([ dispatchWidth, dispatchHeight ], threadsPerThreadgroup: threadgroupSize)
            } else {
                computeEncoder.dispatchThreadgroups([ dispatchWidth, dispatchHeight ], threadsPerThreadgroup: 1)
            }
            
            
            
            computeEncoder.setComputePipelineState(createSignedDistanceFieldPipelineState)
            computeEncoder.setBuffer(buffer, offset: baseLevelOffset,                 index: 0)
            computeEncoder.setBuffer(buffer, offset: upperLevelOffset,                index: 1)

            computeEncoder.setBuffer(buffer, offset: upperLevelOffsetOffset,          index: 2)
            computeEncoder.setBuffer(buffer, offset: levelSizeOffset,                 index: 3)
            computeEncoder.setBuffer(buffer, offset: maxDistanceAndHalfInverseOffset, index: 4)
            
            computeEncoder.setTexture(uncompressedSignedDistanceField, index: 2)
            
            if usingThreadgroups {
                computeEncoder.dispatchThreads([ 8192, textureHeight ], threadsPerThreadgroup: [ 4, 8 ])
            } else {
                computeEncoder.dispatchThreadgroups([ 8192 / 32, textureHeight ], threadsPerThreadgroup: 32)
            }
            
            computeEncoder.endEncoding()
            
            
            
            let blitEncoder = commandBuffer.makeBlitCommandEncoder()!
            blitEncoder.optLabel = "Signed Distance Field Creation - Compress Texture"
            
            blitEncoder.generateMipmaps(for: uncompressedSignedDistanceField)
            blitEncoder.copy(from: uncompressedSignedDistanceField, sourceSlice:      0, sourceLevel:      1,
                             to:   signedDistanceField,             destinationSlice: 0, destinationLevel: 0,
                                                                    sliceCount:       1, levelCount:       1)
            blitEncoder.endEncoding()
            
            commandEncodingSemaphore.signal()
        }
        
        createBitmap()
        
        return (signedDistanceField, commandBuffer)
    }
    
    private static func createSignedDistanceFieldParameters(radius: Int) -> [(simd_ushort2, Float)] {
        var output = [(simd_ushort2, Float)](capacity: radius * radius)
        
        let radiusF = Float(radius)
        var xDistance: Float = 0.5
        
        outer:
        for x in 1...radius {
            var coords = simd_ushort2(UInt16(x), 0)
            output.append((coords, xDistance))
            
            let xDistanceSquared = xDistance * xDistance
            var yDistance: Float = 0.5
            defer { xDistance += 1 }
            
            for y in 1..<x {
                let diagonalDistance = sqrt(fma(yDistance, yDistance, xDistanceSquared))
                if diagonalDistance > radiusF { continue outer }
                
                coords.y = UInt16(y)
                output.append((coords, diagonalDistance))
                output.append((.init(coords.y, coords.x), diagonalDistance))
                
                yDistance += 1
            }
            
            let diagonalDistance = xDistance * sqrt(2)
            if diagonalDistance > radiusF { continue }
            
            coords.y = coords.x
            output.append((coords, diagonalDistance))
        }
        
        output.sort(by: { $0.1 < $1.1 })
        return output
    }

    private static func createSignedDistanceFieldMipmapParameters(level: Int, fullResolutionRadius: Int) -> [(simd_ushort2, Float)] {
        let granularity = 1 << level
        let scaledDownRadius = (fullResolutionRadius - 1 + granularity) >> level
        var output = [(simd_ushort2, Float)](capacity: scaledDownRadius * scaledDownRadius)
        
        let radiusF = Float(fullResolutionRadius)
        let granularityF = Float(granularity)
        var xDistance: Float = 0.5
        
        outer:
        for x in 1...scaledDownRadius {
            var coords = simd_ushort2(UInt16(x), 0)
            output.append((coords, xDistance))
            
            let xDistanceSquared = xDistance * xDistance
            var yDistance: Float = 0.5
            defer { xDistance += granularityF }
            
            for y in 1..<x {
                let diagonalDistance = sqrt(fma(yDistance, yDistance, xDistanceSquared))
                if diagonalDistance > radiusF { continue outer }
                
                coords.y = UInt16(y)
                output.append((coords, diagonalDistance))
                output.append((.init(coords.y, coords.x), diagonalDistance))
                
                yDistance += granularityF
            }
            
            let diagonalDistance = xDistance * sqrt(2)
            if diagonalDistance > radiusF { continue }
            
            coords.y = coords.x
            output.append((coords, diagonalDistance))
        }
        
        output.sort(by: { $0.1 < $1.1 })
        return output
    }
    
}
#endif

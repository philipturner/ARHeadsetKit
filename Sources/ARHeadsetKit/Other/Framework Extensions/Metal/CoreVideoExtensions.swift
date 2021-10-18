//
//  CoreVideoExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 7/22/21.
//

import CoreVideo
import Metal

// High-level wrappers around functions bridging between CoreVideo and Metal

/**
 The namespace containing <doc:cv-metaltexture>.
 
 [`CVMetalTexture`](https://developer.apple.com/documentation/corevideo/cvmetaltexture-q3g) is bridged differently than other CoreVideo and CoreText types. It is a typealias of [`CVBuffer`](https://developer.apple.com/documentation/corevideo/cvbuffer-nfm), so adding members directly to `CVMetalTexture` would add members to `CVBuffer`. To prevent circumvent this name collision, methods and properties of `CVMetalTexture` are added to a separate type.
 */
public enum CV {
    /**
     A value-type wrapper around [`CVMetalTexture`](https://developer.apple.com/documentation/corevideo/cvmetaltexture-q3g).
     
     [`CVMetalTexture`](https://developer.apple.com/documentation/corevideo/cvmetaltexture-q3g) is bridged differently than other CoreVideo and CoreText types. It is a typealias of [`CVBuffer`](https://developer.apple.com/documentation/corevideo/cvbuffer-nfm), so adding members directly to `CVMetalTexture` would add members to `CVBuffer`. To prevent circumvent this name collision, methods and properties of `CVMetalTexture` are added to a separate type.
     */
    public struct MetalTexture {
        @usableFromInline internal var _texture: CVMetalTexture
        
        @inlinable @inline(__always)
        public var asCVMetalTexture: CVMetalTexture { _texture }
        
        @inlinable @inline(__always)
        public init(_ texture: CVMetalTexture) {
            self._texture = texture
        }
        
        /// See [`CVMetalTextureGetTypeID()`](https://developer.apple.com/documentation/corevideo/1457175-cvmetaltexturegettypeid).
        @inlinable @inline(__always)
        public static var typeID: CFTypeID { CVMetalTextureGetTypeID() }
        
        /// See [`CVMetalTextureGetTexture(_:)`](https://developer.apple.com/documentation/corevideo/1456868-cvmetaltexturegettexture).
        @inlinable @inline(__always)
        public var texture: MTLTexture? {
            CVMetalTextureGetTexture(_texture)
        }
        
        /// See [`CVMetalTextureIsFlipped(_:)`](https://developer.apple.com/documentation/corevideo/1456841-cvmetaltextureisflipped).
        @inlinable @inline(__always)
        public var isFlipped: Bool {
            CVMetalTextureIsFlipped(_texture)
        }
        
        /// See [`CVMetalTextureGetCleanTexCoords(_:_:_:_:_:)`](https://developer.apple.com/documentation/corevideo/1457089-cvmetaltexturegetcleantexcoords).
        @inlinable @inline(__always)
        public func getCleanTexCoords(_ lowerLeft:  UnsafeMutablePointer<Float>, _ lowerRight: UnsafeMutablePointer<Float>,
                                      _ upperRight: UnsafeMutablePointer<Float>, _ upperLeft:  UnsafeMutablePointer<Float>) {
            CVMetalTextureGetCleanTexCoords(_texture, lowerLeft, lowerRight, upperRight, upperLeft)
        }
    }
}

public extension Optional where Wrapped == CVMetalTextureCache {
    
    /// See [`CVMetalTextureCacheCreate(_:_:_:_:_:)`](https://developer.apple.com/documentation/corevideo/1456774-cvmetaltexturecachecreate).
    @inlinable @inline(__always)
    init(_ allocator: CFAllocator?, _ cacheAttributes: [CFString : Any]?,
         _ metalDevice: MTLDevice, _ textureAttributes: [CFString : Any]?,
         _ returnRef: UnsafeMutablePointer<CVReturn>? = nil)
    {
        var cacheOut: CVMetalTextureCache?
        let output = CVMetalTextureCacheCreate(allocator,   cacheAttributes as CFDictionary?,
                                               metalDevice, textureAttributes as CFDictionary?, &cacheOut)
        
        if let returnRef = returnRef {
            returnRef.pointee = output
        }
        
        self = cacheOut
    }
    
}

public extension CVMetalTextureCache {
    
    /// See [`CVMetalTextureCacheGetTypeID()`](https://developer.apple.com/documentation/corevideo/1456680-cvmetaltexturecachegettypeid).
    @inlinable @inline(__always)
    static var typeID: CFTypeID { CVMetalTextureCacheGetTypeID() }
    
    /// High-level wrapper over [`CVMetalTextureCacheCreateTextureFromImage(_:_:_:_:_:_:_:_:_:)`](https://developer.apple.com/documentation/corevideo/1456754-cvmetaltexturecachecreatetexture). Texture attrbute dictionary must be specified upon creation of the [`CVMetalTextureCache`](https://developer.apple.com/documentation/corevideo/cvmetaltexturecache), not the [`MTLTexture`](https://developer.apple.com/documentation/metal/mtltexture).
    @inlinable @inline(__always)
    func createMTLTexture(_ sourceImage: CVImageBuffer, _ pixelFormat: MTLPixelFormat,
                          _ width: Int, _ height: Int,  _ planeIndex: Int = 0) -> MTLTexture? {
        createTexture(nil, sourceImage, nil, pixelFormat, width, height, planeIndex)?.texture
    }
    
    /// Raw wrapper over [`CVMetalTextureCacheCreateTextureFromImage(_:_:_:_:_:_:_:_:_:)`](https://developer.apple.com/documentation/corevideo/1456754-cvmetaltexturecachecreatetexture). `createMTLTexture(_:_:_:_:_:)` is a more ergonomic alternative.
    @inlinable @inline(__always)
    func createTexture(_ allocator: CFAllocator?, _ sourceImage: CVImageBuffer,
                       _ textureAttributes: [CFString : Any]?,
                       _ pixelFormat: MTLPixelFormat, _ width: Int, _ height: Int, _ planeIndex: Int,
                       _ returnRef: UnsafeMutablePointer<CVReturn>? = nil) -> CV.MetalTexture?
    {
        var textureOut: CVMetalTexture?
        let output = CVMetalTextureCacheCreateTextureFromImage(allocator, self, sourceImage,
                                                               textureAttributes as CFDictionary?,
                                                               pixelFormat, width, height, planeIndex, &textureOut)
        
        if let returnRef = returnRef {
            returnRef.pointee = output
        }
        
        guard let texture = textureOut else {
            return nil
        }
        
        return CV.MetalTexture(texture)
    }
    
    /// See [`CVMetalTextureCacheFlush(_:_:)`](https://developer.apple.com/documentation/corevideo/1457001-cvmetaltexturecacheflush).
    @inlinable @inline(__always)
    func flush(_ options: CVOptionFlags) {
        CVMetalTextureCacheFlush(self, options)
    }
    
}

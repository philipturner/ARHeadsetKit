//
//  simdExtensions.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import simd

// Vectorized math functions

@inlinable @inline(__always) public func fma(_ x: simd_float2, _ y: simd_float2, _ z: simd_float2) -> simd_float2 { __tg_fma(x, y, z) }
@inlinable @inline(__always) public func fma(_ x: simd_float3, _ y: simd_float3, _ z: simd_float3) -> simd_float3 { __tg_fma(x, y, z) }
@inlinable @inline(__always) public func fma(_ x: simd_float4, _ y: simd_float4, _ z: simd_float4) -> simd_float4 { __tg_fma(x, y, z) }
@inlinable @inline(__always) public func fma(_ x: simd_double2, _ y: simd_double2, _ z: simd_double2) -> simd_double2 { __tg_fma(x, y, z) }

@inlinable @inline(__always) public func fma(_ x: Float, _ y: simd_float2, _ z: simd_float2) -> simd_float2 { fma(.init(repeating: x), y, z) }
@inlinable @inline(__always) public func fma(_ x: simd_float2, _ y: Float, _ z: simd_float2) -> simd_float2 { fma(y, x, z) }
@inlinable @inline(__always) public func fma(_ x: simd_float2, _ y: simd_float2, _ z: Float) -> simd_float2 { fma(x, y, .init(repeating: z)) }
@inlinable @inline(__always) public func fma(_ x: Float,       _ y: simd_float2, _ z: Float) -> simd_float2 { fma(x, y, .init(repeating: z)) }
@inlinable @inline(__always) public func fma(_ x: simd_float2, _ y: Float,       _ z: Float) -> simd_float2 { fma(y, x, z) }

@inlinable @inline(__always) public func fma(_ x: Float, _ y: simd_float3, _ z: simd_float3) -> simd_float3 { fma(.init(repeating: x), y, z) }
@inlinable @inline(__always) public func fma(_ x: simd_float3, _ y: Float, _ z: simd_float3) -> simd_float3 { fma(y, x, z) }
@inlinable @inline(__always) public func fma(_ x: simd_float3, _ y: simd_float3, _ z: Float) -> simd_float3 { fma(x, y, .init(repeating: z)) }
@inlinable @inline(__always) public func fma(_ x: Float,       _ y: simd_float3, _ z: Float) -> simd_float3 { fma(x, y, .init(repeating: z)) }
@inlinable @inline(__always) public func fma(_ x: simd_float3, _ y: Float,       _ z: Float) -> simd_float3 { fma(y, x, z) }

@inlinable @inline(__always) public func fma(_ x: Float, _ y: simd_float4, _ z: simd_float4) -> simd_float4 { fma(.init(repeating: x), y, z) }
@inlinable @inline(__always) public func fma(_ x: simd_float4, _ y: Float, _ z: simd_float4) -> simd_float4 { fma(y, x, z) }
@inlinable @inline(__always) public func fma(_ x: simd_float4, _ y: simd_float4, _ z: Float) -> simd_float4 { fma(x, y, .init(repeating: z)) }
@inlinable @inline(__always) public func fma(_ x: Float,       _ y: simd_float4, _ z: Float) -> simd_float4 { fma(x, y, .init(repeating: z)) }
@inlinable @inline(__always) public func fma(_ x: simd_float4, _ y: Float,       _ z: Float) -> simd_float4 { fma(y, x, z) }

@inlinable @inline(__always) public func fma(_ x: Double, _ y: simd_double2, _ z: simd_double2) -> simd_double2 { fma(.init(repeating: x), y, z) }
@inlinable @inline(__always) public func fma(_ x: simd_double2, _ y: Double, _ z: simd_double2) -> simd_double2 { fma(y, x, z) }
@inlinable @inline(__always) public func fma(_ x: simd_double2, _ y: simd_double2, _ z: Double) -> simd_double2 { fma(x, y, .init(repeating: z)) }
@inlinable @inline(__always) public func fma(_ x: Double,       _ y: simd_double2, _ z: Double) -> simd_double2 { fma(x, y, .init(repeating: z)) }
@inlinable @inline(__always) public func fma(_ x: simd_double2, _ y: Double,       _ z: Double) -> simd_double2 { fma(y, x, z) }



@inlinable @inline(__always) public func sqrt(_ x: simd_float2)  -> simd_float2  { __tg_sqrt(x) }
@inlinable @inline(__always) public func sqrt(_ x: simd_float3)  -> simd_float3  { __tg_sqrt(x) }
@inlinable @inline(__always) public func sqrt(_ x: simd_float4)  -> simd_float4  { __tg_sqrt(x) }
@inlinable @inline(__always) public func sqrt(_ x: simd_double2) -> simd_double2 { __tg_sqrt(x) }

@inlinable @inline(__always) public func cbrt(_ x: simd_float2)  -> simd_float2  { __tg_cbrt(x) }
@inlinable @inline(__always) public func cbrt(_ x: simd_float3)  -> simd_float3  { __tg_cbrt(x) }
@inlinable @inline(__always) public func cbrt(_ x: simd_float4)  -> simd_float4  { __tg_cbrt(x) }
@inlinable @inline(__always) public func cbrt(_ x: simd_double2) -> simd_double2 { __tg_cbrt(x) }

@inlinable @inline(__always) public func copysign(_ x: simd_float2,  _ y: simd_float2)  -> simd_float2  { __tg_copysign(x, y) }
@inlinable @inline(__always) public func copysign(_ x: simd_float3,  _ y: simd_float3)  -> simd_float3  { __tg_copysign(x, y) }
@inlinable @inline(__always) public func copysign(_ x: simd_float4,  _ y: simd_float4)  -> simd_float4  { __tg_copysign(x, y) }
@inlinable @inline(__always) public func copysign(_ x: simd_double2, _ y: simd_double2) -> simd_double2 { __tg_copysign(x, y) }

@inlinable @inline(__always) public func fmod(_ x: simd_float2,  _ y: simd_float2)  -> simd_float2  { __tg_fmod(x, y) }
@inlinable @inline(__always) public func fmod(_ x: simd_float3,  _ y: simd_float3)  -> simd_float3  { __tg_fmod(x, y) }
@inlinable @inline(__always) public func fmod(_ x: simd_float4,  _ y: simd_float4)  -> simd_float4  { __tg_fmod(x, y) }
@inlinable @inline(__always) public func fmod(_ x: simd_double2, _ y: simd_double2) -> simd_double2 { __tg_fmod(x, y) }



@inlinable @inline(__always) public func sin(_ x: simd_float2)  -> simd_float2  { __tg_sin(x) }
@inlinable @inline(__always) public func sin(_ x: simd_float3)  -> simd_float3  { __tg_sin(x) }
@inlinable @inline(__always) public func sin(_ x: simd_float4)  -> simd_float4  { __tg_sin(x) }
@inlinable @inline(__always) public func sin(_ x: simd_double2) -> simd_double2 { __tg_sin(x) }

@inlinable @inline(__always) public func cos(_ x: simd_float2)  -> simd_float2  { __tg_cos(x) }
@inlinable @inline(__always) public func cos(_ x: simd_float3)  -> simd_float3  { __tg_cos(x) }
@inlinable @inline(__always) public func cos(_ x: simd_float4)  -> simd_float4  { __tg_cos(x) }
@inlinable @inline(__always) public func cos(_ x: simd_double2) -> simd_double2 { __tg_cos(x) }

@inlinable @inline(__always) public func tan(_ x: simd_float2)  -> simd_float2  { __tg_tan(x) }
@inlinable @inline(__always) public func tan(_ x: simd_float3)  -> simd_float3  { __tg_tan(x) }
@inlinable @inline(__always) public func tan(_ x: simd_float4)  -> simd_float4  { __tg_tan(x) }
@inlinable @inline(__always) public func tan(_ x: simd_double2) -> simd_double2 { __tg_tan(x) }



@inlinable @inline(__always) public func log(_ x: simd_float2)  -> simd_float2  { __tg_log(x) }
@inlinable @inline(__always) public func log(_ x: simd_float3)  -> simd_float3  { __tg_log(x) }
@inlinable @inline(__always) public func log(_ x: simd_float4)  -> simd_float4  { __tg_log(x) }
@inlinable @inline(__always) public func log(_ x: simd_double2) -> simd_double2 { __tg_log(x) }

@inlinable @inline(__always) public func log2(_ x: simd_float2)  -> simd_float2  { __tg_log2(x) }
@inlinable @inline(__always) public func log2(_ x: simd_float3)  -> simd_float3  { __tg_log2(x) }
@inlinable @inline(__always) public func log2(_ x: simd_float4)  -> simd_float4  { __tg_log2(x) }
@inlinable @inline(__always) public func log2(_ x: simd_double2) -> simd_double2 { __tg_log2(x) }

@inlinable @inline(__always) public func log10(_ x: simd_float2)  -> simd_float2  { __tg_log10(x) }
@inlinable @inline(__always) public func log10(_ x: simd_float3)  -> simd_float3  { __tg_log10(x) }
@inlinable @inline(__always) public func log10(_ x: simd_float4)  -> simd_float4  { __tg_log10(x) }
@inlinable @inline(__always) public func log10(_ x: simd_double2) -> simd_double2 { __tg_log10(x) }

@inlinable @inline(__always) public func pow(_ x: simd_float2,  _ y: simd_float2)  -> simd_float2  { __tg_pow(x, y) }
@inlinable @inline(__always) public func pow(_ x: simd_float3,  _ y: simd_float3)  -> simd_float3  { __tg_pow(x, y) }
@inlinable @inline(__always) public func pow(_ x: simd_float4,  _ y: simd_float4)  -> simd_float4  { __tg_pow(x, y) }
@inlinable @inline(__always) public func pow(_ x: simd_double2, _ y: simd_double2) -> simd_double2 { __tg_pow(x, y) }

// Half Precision Vectors and Matrices

#if arch(arm64)
public typealias simd_half2 = SIMD2<Float16>

public extension simd_half2 {
    @inlinable @inline(__always)
    init(_ x: Float, _ y: Float) {
        self.init(simd_float2(x, y))
    }
    
    @inlinable @inline(__always)
    init(_ vector: simd_half3) {
        self.init(vector.x, vector.y)
    }
    
    @inlinable @inline(__always)
    init(_ vector: simd_half4) {
        self.init(vector.x, vector.y)
    }
    
    @inlinable @inline(__always)
    init(_ vector: simd_float3) {
        self.init(simd_float2(vector.x, vector.y))
    }
    
    @inlinable @inline(__always)
    init(_ vector: simd_float4) {
        self.init(vector.lowHalf)
    }
}

public struct simd_packed_half2: Equatable {
    public var x: Float16
    public var y: Float16
    
    @inlinable @inline(__always)
    public var unpacked: simd_half2 {
        simd_half2(x, y)
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ x: Float16, _ y: Float16) {
        self.x = x
        self.y = y
    }
    
    @inlinable @inline(__always)
    public init(_ x: Float, _ y: Float) {
        self.init(Float16(x), Float16(y))
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ vector: simd_half2) {
        self.init(vector.x, vector.y)
    }
    
    @inlinable @inline(__always)
    public init(_ vector: simd_float2) {
        self.init(vector.x, vector.y)
    }
}

public struct simd_half2x2: Equatable {
    public var columns: (simd_half2, simd_half2)
    
    @inlinable @inline(__always)
    public static func == (lhs: simd_half2x2, rhs: simd_half2x2) -> Bool {
        lhs.columns.0 == rhs.columns.0 &&
        lhs.columns.1 == rhs.columns.1
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_half2, _ col2: simd_half2) {
        columns = (col1, col2)
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_float2, _ col2: simd_float2) {
        columns = (
            simd_half2(col1),
            simd_half2(col2)
        )
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half2x2) {
        columns = (
            simd_half2(matrix.columns.0),
            simd_half2(matrix.columns.1)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half3x3) {
        columns = (
            simd_half2(matrix.columns.0),
            simd_half2(matrix.columns.1)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half4x4) {
        columns = (
            simd_half2(matrix.columns.0),
            simd_half2(matrix.columns.1)
        )
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float2x2) {
        columns = (
            simd_half2(matrix.columns.0),
            simd_half2(matrix.columns.1)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float3x3) {
        columns = (
            simd_half2(matrix.columns.0),
            simd_half2(matrix.columns.1)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float4x4) {
        columns = (
            simd_half2(matrix.columns.0),
            simd_half2(matrix.columns.1)
        )
    }
}

public let matrix_identity_half2x2 = simd_half2x2([1, 0],
                                       simd_half2([0, 1]))

public struct simd_half3x2: Equatable {
    public var columns: (simd_half2, simd_half2, simd_half2)
    
    @inlinable @inline(__always)
    public static func == (lhs: simd_half3x2, rhs: simd_half3x2) -> Bool {
        lhs.columns.0 == rhs.columns.0 &&
        lhs.columns.1 == rhs.columns.1 &&
        lhs.columns.2 == rhs.columns.2
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_half2, _ col2: simd_half2, _ col3: simd_half2) {
        columns = (col1, col2, col3)
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_float2, _ col2: simd_float2, _ col3: simd_float2) {
        columns = (
            simd_half2(col1),
            simd_half2(col2),
            simd_half2(col3)
        )
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half3x2) {
        columns = (
            simd_half2(matrix.columns.0),
            simd_half2(matrix.columns.1),
            simd_half2(matrix.columns.2)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float3x2) {
        columns = (
            simd_half2(matrix.columns.0),
            simd_half2(matrix.columns.1),
            simd_half2(matrix.columns.2)
        )
    }
}

public typealias simd_half3 = SIMD3<Float16>

public extension simd_half3 {
    @inlinable @inline(__always)
    init(_ vector: simd_half3) {
        self.init(vector.x, vector.y, vector.z)
    }
    
    @inlinable @inline(__always)
    init(_ vector: simd_half4) {
        self.init(vector.x, vector.y, vector.z)
    }
    
    
    
    @inlinable @inline(__always)
    init(_ x: Float, _ y: Float, _ z: Float) {
        self.init(simd_float3(x, y, z))
    }
    
    @inlinable @inline(__always)
    init(_ xy: simd_float2, _ z: Float) {
        self.init(xy.x, xy.y, z)
    }
    
    @inlinable @inline(__always)
    init(_ vector: simd_float4) {
        self.init(vector.x, vector.y, vector.z)
    }
}

public struct simd_packed_half3: Equatable {
    public var x: Float16
    public var y: Float16
    public var z: Float16
    
    @inlinable @inline(__always)
    public var unpacked: simd_half3 {
        simd_half3(x, y, z)
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ x: Float16, _ y: Float16, _ z: Float16) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    @inlinable @inline(__always)
    public init(_ x: Float, _ y: Float, _ z: Float) {
        self.init(Float16(x), Float16(y), Float16(z))
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ vector: simd_half3) {
        self.init(vector.x, vector.y, vector.z)
    }
    
    @inlinable @inline(__always)
    public init(_ vector: simd_float3) {
        self.init(vector.x, vector.y, vector.z)
    }
}

public struct simd_half2x3: Equatable {
    public var columns: (simd_half3, simd_half3)
    
    @inlinable @inline(__always)
    public static func == (lhs: simd_half2x3, rhs: simd_half2x3) -> Bool {
        lhs.columns.0 == rhs.columns.0 &&
        lhs.columns.1 == rhs.columns.1
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_half3, _ col2: simd_half3) {
        columns = (col1, col2)
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_float3, _ col2: simd_float3) {
        columns = (
            simd_half3(col1),
            simd_half3(col2)
        )
    }
    
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half2x3) {
        columns = (
            simd_half3(matrix.columns.0),
            simd_half3(matrix.columns.1)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float2x3) {
        columns = (
            simd_half3(matrix.columns.0),
            simd_half3(matrix.columns.1)
        )
    }
}

public struct simd_half3x3: Equatable {
    public var columns: (simd_half3, simd_half3, simd_half3)
    
    @inlinable @inline(__always)
    public static func == (lhs: simd_half3x3, rhs: simd_half3x3) -> Bool {
        lhs.columns.0 == rhs.columns.0 &&
        lhs.columns.1 == rhs.columns.1 &&
        lhs.columns.2 == rhs.columns.2
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_half3, _ col2: simd_half3, _ col3: simd_half3) {
        columns = (col1, col2, col3)
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_float3, _ col2: simd_float3, _ col3: simd_float3) {
        columns = (
            simd_half3(col1),
            simd_half3(col2),
            simd_half3(col3)
        )
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half3x3) {
        columns = (
            simd_half3(matrix.columns.0),
            simd_half3(matrix.columns.1),
            simd_half3(matrix.columns.2)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half4x4) {
        columns = (
            simd_half3(matrix.columns.0),
            simd_half3(matrix.columns.1),
            simd_half3(matrix.columns.2)
        )
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float3x3) {
        columns = (
            simd_half3(matrix.columns.0),
            simd_half3(matrix.columns.1),
            simd_half3(matrix.columns.2)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float4x4) {
        columns = (
            simd_half3(matrix.columns.0),
            simd_half3(matrix.columns.1),
            simd_half3(matrix.columns.2)
        )
    }
}

public let matrix_identity_half3x3 = simd_half3x3([1, 0, 0],
                                       simd_half3([0, 1, 0]),
                                                  [0, 0, 1])
public struct simd_half4x3: Equatable {
    public var columns: (simd_half3, simd_half3, simd_half3, simd_half3)
    
    @inlinable @inline(__always)
    public static func == (lhs: simd_half4x3, rhs: simd_half4x3) -> Bool {
        lhs.columns.0 == rhs.columns.0 &&
        lhs.columns.1 == rhs.columns.1 &&
        lhs.columns.2 == rhs.columns.2 &&
        lhs.columns.3 == rhs.columns.3
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_half3, _ col2: simd_half3, _ col3: simd_half3, _ col4: simd_half3) {
        columns = (col1, col2, col3, col4)
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_float3, _ col2: simd_float3, _ col3: simd_float3, _ col4: simd_float3) {
        columns = (
            simd_half3(col1),
            simd_half3(col2),
            simd_half3(col3),
            simd_half3(col4)
        )
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half4x3) {
        columns = (
            simd_half3(matrix.columns.0),
            simd_half3(matrix.columns.1),
            simd_half3(matrix.columns.2),
            simd_half3(matrix.columns.3)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float4x3) {
        columns = (
            simd_half3(matrix.columns.0),
            simd_half3(matrix.columns.1),
            simd_half3(matrix.columns.2),
            simd_half3(matrix.columns.3)
        )
    }
}

public typealias simd_half4 = SIMD4<Float16>

public extension simd_half4 {
    @inlinable @inline(__always)
    init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.init(simd_float4(x, y, z, w))
    }
    
    @inlinable @inline(__always)
    init(_ xy: simd_float2, _ zw: simd_float2) {
        self.init(xy.x, xy.y, zw.x, zw.y)
    }
    
    @inlinable @inline(__always)
    init(_ xyz: simd_float3, _ w: Float) {
        self.init(xyz.x, xyz.y, xyz.z, w)
    }
}

public struct simd_packed_half4: Equatable {
    public var x: Float16
    public var y: Float16
    public var z: Float16
    public var w: Float16
    
    @inlinable @inline(__always)
    public var unpacked: simd_half4 {
        simd_half4(x, y, z, w)
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ x: Float16, _ y: Float16, _ z: Float16, _ w: Float16) {
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
    
    @inlinable @inline(__always)
    public init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.init(Float16(x), Float16(y), Float16(z), Float16(w))
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ vector: simd_half4) {
        self.init(vector.x, vector.y, vector.z, vector.w)
    }
    
    @inlinable @inline(__always)
    public init(_ vector: simd_float4) {
        self.init(vector.x, vector.y, vector.z, vector.w)
    }
}

public struct simd_half4x4: Equatable {
    public var columns: (simd_half4, simd_half4, simd_half4, simd_half4)
    
    @inlinable @inline(__always)
    public static func == (lhs: simd_half4x4, rhs: simd_half4x4) -> Bool {
        lhs.columns.0 == rhs.columns.0 &&
        lhs.columns.1 == rhs.columns.1 &&
        lhs.columns.2 == rhs.columns.2 &&
        lhs.columns.3 == rhs.columns.3
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_half4, _ col2: simd_half4, _ col3: simd_half4, _ col4: simd_half4) {
        columns = (col1, col2, col3, col4)
    }
    
    @inlinable @inline(__always)
    public init(_ col1: simd_float4, _ col2: simd_float4, _ col3: simd_float4, _ col4: simd_float4) {
        columns = (
            simd_half4(col1),
            simd_half4(col2),
            simd_half4(col3),
            simd_half4(col4)
        )
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_half4x4) {
        columns = (
            simd_half4(matrix.columns.0),
            simd_half4(matrix.columns.1),
            simd_half4(matrix.columns.2),
            simd_half4(matrix.columns.3)
        )
    }
    
    @inlinable @inline(__always)
    public init(_ matrix: simd_float4x4) {
        columns = (
            simd_half4(matrix.columns.0),
            simd_half4(matrix.columns.1),
            simd_half4(matrix.columns.2),
            simd_half4(matrix.columns.3)
        )
    }
}

public let matrix_identity_half4x4 = simd_half4x4([1, 0, 0, 0],
                                       simd_half4([0, 1, 0, 0]),
/* Other Vector Types */                          [0, 0, 1, 0],
                                                  [0, 0, 0, 1])
#endif
public struct simd_packed_float3: Equatable {
    public var x: Float
    public var y: Float
    public var z: Float
    
    @inlinable @inline(__always)
    public var unpacked: simd_float3 {
        simd_float3(x, y, z)
    }
    
    
    
    @inlinable @inline(__always)
    public init(_ x: Float, _ y: Float, _ z: Float) {
        self.x = x
        self.y = y
        self.z = z
    }
    
    @inlinable @inline(__always)
    public init(_ vector: simd_float3) {
        self.init(vector.x, vector.y, vector.z)
    }
    
    
    
    #if arch(arm64)
    @inlinable @inline(__always)
    public init(_ x: Float16, _ y: Float16, _ z: Float16) {
        self.init(Float(x), Float(y), Float(z))
    }
    
    @inlinable @inline(__always)
    public init(_ vector: simd_half3) {
        self.init(vector.x, vector.y, vector.z)
    }
    #endif
}

public extension __float2 {
    var sinCosVector: simd_float2 { [__sinval, __cosval] }
    var cosSinVector: simd_float2 { [__cosval, __sinval] }
}

public extension simd_float4x2 {
    var array: [simd_float2] {
        [columns.0, columns.1, columns.2, columns.3]
    }
}

public extension simd_float4x3 {
    var array: [simd_float3] {
        [columns.0, columns.1, columns.2, columns.3]
    }
}

// Integer vectors

public struct simd_packed_short3: Equatable {
    public var x: Int16
    public var y: Int16
    public var z: Int16
    
    @inlinable @inline(__always)
    public init(_ vector: simd_short3) {
        x = vector.x
        y = vector.y
        z = vector.z
    }
    
    @inlinable @inline(__always)
    public var unpackedVector: simd_short3 { .init(x, y, z) }
}

public struct simd_packed_ushort3: Equatable {
    public var x: UInt16
    public var y: UInt16
    public var z: UInt16
    
    @inlinable @inline(__always)
    public init(_ vector: simd_ushort3) {
        x = vector.x
        y = vector.y
        z = vector.z
    }
    
    @inlinable @inline(__always)
    public var unpackedVector: simd_ushort3 { .init(x, y, z) }
}

public struct simd_packed_int3: Equatable {
    public var x: Int32
    public var y: Int32
    public var z: Int32
    
    @inlinable @inline(__always)
    public init(_ vector: simd_int3) {
        x = vector.x
        y = vector.y
        z = vector.z
    }
    
    @inlinable @inline(__always)
    public var unpackedVector: simd_int3 { .init(x, y, z) }
}

public struct simd_packed_uint3: Equatable {
    public var x: UInt32
    public var y: UInt32
    public var z: UInt32
    
    @inlinable @inline(__always)
    public init(_ vector: simd_uint3) {
        x = vector.x
        y = vector.y
        z = vector.z
    }
    
    @inlinable @inline(__always)
    public var unpackedVector: simd_uint3 { .init(x, y, z) }
}

// Boolean vectors

public struct simd_bool2: Equatable {
    @usableFromInline internal var _mask: simd_uchar2
    
    @inlinable @inline(__always)
    public init(_ x: Bool, _ y: Bool) {
        _mask = simd_uchar2(x ? 1 : 0, y ? 1 : 0)
    }
    
    @inlinable @inline(__always)
    public subscript(_ index: Int) -> Bool {
        get { _mask[index] != 0 }
        set {
            _mask[index] = newValue ? 1 : 0
        }
    }
}

public struct simd_bool3: Equatable {
    @usableFromInline internal var _mask: simd_uchar3
    
    @inlinable @inline(__always)
    public init(_ x: Bool, _ y: Bool, _ z: Bool) {
        _mask = simd_uchar3(x ? 1 : 0, y ? 1 : 0,
                            z ? 1 : 0)
    }
    
    @inlinable @inline(__always)
    public subscript(_ index: Int) -> Bool {
        get { _mask[index] != 0 }
        set {
            _mask[index] = newValue ? 1 : 0
        }
    }
}

public struct simd_bool4: Equatable {
    @usableFromInline internal var _mask: simd_uchar4
    
    @inlinable @inline(__always)
    public init(_ x: Bool, _ y: Bool, _ z: Bool, _ w: Bool) {
        _mask = simd_uchar4(x ? 1 : 0, y ? 1 : 0,
                            z ? 1 : 0, w ? 1 : 0)
    }
    
    @inlinable @inline(__always)
    public subscript(_ index: Int) -> Bool {
        get { _mask[index] != 0 }
        set {
            _mask[index] = newValue ? 1 : 0
        }
    }
}

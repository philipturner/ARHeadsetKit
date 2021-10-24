//
//  MathUtilities.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 4/13/21.
//

import simd

/// Rounds an integer up to the nearest power of 2.
@inlinable @inline(__always)
public func roundUpToPowerOf2(_ input: Int) -> Int {
    1 << (64 - max(0, input - 1).leadingZeroBitCount)
}

/// The color of black-body radiation at a specific temperature.
@inlinable
public func kelvinToRGB(_ temperature: Double) -> simd_float3 {
    var output: simd_float3
    
    if temperature <= 6600 {
        let scale: simd_double2 = [99.4708025861, 138.5177312231] / 255
        let translation: simd_double2 = [-161.1195681661, -305.044792730] / 255
        
        let temperatureVector = fma(temperature, [0.01, 0.01], [0, -10])
        let green_blue = simd_float2(fma(log(temperatureVector), scale, translation))
        
        output = .init(1, green_blue[0], green_blue[1])
    } else {
        let scale: simd_double2 = [329.698727446, 288.1221695283] / 255
        let powers: simd_double2 = [-0.1332047592, -0.0755148492]
        
        let temperatureVector = fma(temperature, [0.01, 0.01], [-60, 0])
        let red_green = simd_float2(pow(temperatureVector, powers) * scale)
        
        output = .init(red_green, 1)
    }
    
    return clamp(output, min: 0, max: 1)
}

// MARK: - Angle utilities

@inlinable public func degreesToRadians<T: BinaryFloatingPoint>(_ x: T) -> T { x * (.pi / 180) }
@inlinable public func radiansToDegrees<T: BinaryFloatingPoint>(_ x: T) -> T { x * (180 / .pi) }

/// Equivalent to [`simd_slerp(_:_:_:)`](https://developer.apple.com/documentation/accelerate/2883426-simd_slerp), but operates on direction vectors.
@inlinable
public func simd_slerp(from start: simd_float3, to end: simd_float3, t: Float) -> simd_float3 {
    var rotation = simd_quatf(from: start, to: end)
    let rotationAngle = t * rotation.angle
    
    rotation = simd_quatf(angle: rotationAngle, axis: rotation.axis)
    return rotation.act(start)
}

/// A modified `fmod(_:)` operation that always returns a positive number.
@inlinable @inline(__always)
public func positiveRemainder(_ a: Float, _ b: Float) -> Float {
    var remainder = fmod(a, b)
    
    if remainder < 0 {
        remainder += b
    }
    
    return remainder
}

/// A modified `fmod(_:)` operation that always returns a positive number.
@inlinable @inline(__always)
public func positiveRemainder(_ a: simd_float2, _ b: simd_float2) -> simd_float2 {
    var remainders = fmod(a, b)
    let mask = remainders .< 0
    
    if any(mask) {
        let adjustedRemainders = remainders + b
        remainders.replace(with: adjustedRemainders, where: mask)
    }
    
    return remainders
}

/// A modified `fmod(_:)` operation that always returns a positive number.
@inlinable @inline(__always)
public func positiveRemainder(_ a: simd_float3, _ b: simd_float3) -> simd_float3 {
    var remainders = fmod(a, b)
    let mask = remainders .< 0
    
    if any(mask) {
        let adjustedRemainders = remainders + b
        remainders.replace(with: adjustedRemainders, where: mask)
    }
    
    return remainders
}

/// A modified `fmod(_:)` operation that always returns a positive number.
@inlinable @inline(__always)
public func positiveRemainder(_ a: simd_float4, _ b: simd_float4) -> simd_float4 {
    var remainders = fmod(a, b)
    let mask = remainders .< 0
    
    if any(mask) {
        let adjustedRemainders = remainders + b
        remainders.replace(with: adjustedRemainders, where: mask)
    }
    
    return remainders
}

/// A modified `fmod(_:)` operation that always returns a positive number.
@inlinable @inline(__always)
public func positiveRemainder(_ a: Double, _ b: Double) -> Double {
    var remainder = fmod(a, b)
    
    if remainder < 0 {
        remainder += b
    }
    
    return remainder
}

/// A modified `fmod(_:)` operation that always returns a positive number.
@inlinable @inline(__always)
public func positiveRemainder(_ a: simd_double2, _ b: simd_double2) -> simd_double2 {
    var remainders = fmod(a, b)
    let mask = remainders .< 0
    
    if any(mask) {
        let adjustedRemainders = remainders + b
        remainders.replace(with: adjustedRemainders, where: mask)
    }
    
    return remainders
}

/// Calculate an angle's cosine using its sine, eliminating a costly call to `cos(_:)`.
@inlinable @inline(__always)
public func getCos(sinval: Float, angle: Float) -> Float {
    let angleMod = positiveRemainder(angle, 2 * .pi)
    var cosval = sqrt(fma(-sinval, sinval, 1))
    
    if angleMod > 0.5 * .pi, angleMod < 1.5 * .pi {
        cosval = -cosval
    }
    
    return cosval
}

/// Calculate an angle's cosine using its sine, eliminating a costly call to `cos(_:)`.
@inlinable @inline(__always)
public func getCos(sinval: simd_float2, angle: simd_float2) -> simd_float2 {
    let angleMod = positiveRemainder(angle, .init(repeating: 2 * .pi))
    let cosval = sqrt(fma(-sinval, sinval, .init(repeating: 1)))
    
    let mask1 = angleMod .> 0.5 * .pi
    let mask2 = angleMod .< 1.5 * .pi
    
    return cosval.replacing(with: -cosval, where: mask1 .& mask2)
}

/// Calculate an angle's cosine using its sine, eliminating a costly call to `cos(_:)`.
@inlinable @inline(__always)
public func getCos(sinval: simd_float3, angle: simd_float3) -> simd_float3 {
    let angleMod = positiveRemainder(angle, .init(repeating: 2 * .pi))
    let cosval = sqrt(fma(-sinval, sinval, .init(repeating: 1)))
    
    let mask1 = angleMod .> 0.5 * .pi
    let mask2 = angleMod .< 1.5 * .pi
    
    return cosval.replacing(with: -cosval, where: mask1 .& mask2)
}

/// Calculate an angle's cosine using its sine, eliminating a costly call to `cos(_:)`.
@inlinable @inline(__always)
public func getCos(sinval: simd_float4, angle: simd_float4) -> simd_float4 {
    let angleMod = positiveRemainder(angle, .init(repeating: 2 * .pi))
    let cosval = sqrt(fma(-sinval, sinval, .init(repeating: 1)))
    
    let mask1 = angleMod .> 0.5 * .pi
    let mask2 = angleMod .< 1.5 * .pi
    
    return cosval.replacing(with: -cosval, where: mask1 .& mask2)
}

/// Calculate an angle's cosine using its sine, eliminating a costly call to `cos(_:)`.
@inlinable @inline(__always)
public func getCos(sinval: Double, angle: Double) -> Double {
    let angleMod = positiveRemainder(angle, 2 * .pi)
    var cosval = sqrt(fma(-sinval, sinval, 1))
    
    if angleMod > 0.5 * .pi, angleMod < 1.5 * .pi {
        cosval = -cosval
    }
    
    return cosval
}

/// Calculate an angle's cosine using its sine, eliminating a costly call to `cos(_:)`.
@inlinable @inline(__always)
public func getCos(sinval: simd_double2, angle: simd_double2) -> simd_double2 {
    let angleMod = positiveRemainder(angle, .init(repeating: 2 * .pi))
    let cosval = sqrt(fma(-sinval, sinval, .init(repeating: 1)))
    
    let mask1 = angleMod .> 0.5 * .pi
    let mask2 = angleMod .< 1.5 * .pi
    
    return cosval.replacing(with: -cosval, where: mask1 .& mask2)
}

// MARK: - Accelerated dot products

/// Perform multiple dot products at once to maximize performance, with an optional zero-cost add.
@inlinable @inline(__always)
public func dotAdd(_ lhs: simd_float2, _ mid: simd_float2, rhs: Float = 0) -> Float {
    fma(lhs.x, mid.x, fma(lhs.y, mid.y, rhs))
}

/// Perform multiple dot products at once to maximize performance, with an optional zero-cost add.
@inlinable @inline(__always)
public func dotAdd(_ lhs: simd_float3, _ mid: simd_float3, rhs: Float = 0) -> Float {
    var results = lhs * mid
    
    results.x += results.y
    results.z += rhs
    
    return results.x + results.z
}

/// Perform multiple dot products at once to maximize performance, with an optional zero-cost add.
@inlinable @inline(__always)
public func dotAdd(_ lhs0: simd_float2, _ mid0: simd_float2, rhs0: Float = 0,
                   _ lhs1: simd_float2, _ mid1: simd_float2, rhs1: Float = 0) -> simd_float2
{
    let out = fma(.init(lhs0.y, lhs1.y),
                  .init(mid0.y, mid1.y),
                  .init(rhs0,   rhs1))
    
    return fma(.init(lhs0.x, lhs1.x),
               .init(mid0.x, mid1.x), out)
}

/// Perform multiple dot products at once to maximize performance, with an optional zero-cost add.
@inlinable @inline(__always)
public func dotAdd(_ lhs0: simd_float3, _ mid0: simd_float3, rhs0: Float = 0,
                   _ lhs1: simd_float3, _ mid1: simd_float3, rhs1: Float = 0) -> simd_float2
{
    var out = fma(.init(lhs0.z, lhs1.z),
                  .init(mid0.z, mid1.z),
                  .init(rhs0,   rhs1))
    
    out = fma(.init(lhs0.y, lhs1.y),
              .init(mid0.y, mid1.y), out)
    
    return fma(.init(lhs0.x, lhs1.x),
               .init(mid0.x, mid1.x), out)
}

/// Perform multiple dot products at once to maximize performance, with an optional zero-cost add.
@inlinable @inline(__always)
public func dotAdd(_ lhs0: simd_float2, _ mid0: simd_float2, rhs0: Float = 0,
                   _ lhs1: simd_float2, _ mid1: simd_float2, rhs1: Float = 0,
                   _ lhs2: simd_float2, _ mid2: simd_float2, rhs2: Float = 0) -> simd_float3
{
    let out = fma(.init(lhs0.y, lhs1.y, lhs2.y),
                  .init(mid0.y, mid1.y, mid2.y),
                  .init(rhs0,   rhs1,   rhs2))
    
    return fma(.init(lhs0.x, lhs1.x, lhs2.x),
               .init(mid0.x, mid1.x, mid2.x), out)
}

/// Perform multiple dot products at once to maximize performance, with an optional zero-cost add.
@inlinable @inline(__always)
public func dotAdd(_ lhs0: simd_float3, _ mid0: simd_float3, rhs0: Float = 0,
                   _ lhs1: simd_float3, _ mid1: simd_float3, rhs1: Float = 0,
                   _ lhs2: simd_float3, _ mid2: simd_float3, rhs2: Float = 0) -> simd_float3
{
    var out = fma(.init(lhs0.z, lhs1.z, lhs2.z),
                  .init(mid0.z, mid1.z, mid2.z),
                  .init(rhs0,   rhs1,   rhs2))
    
    out = fma(.init(lhs0.y, lhs1.y, lhs2.y),
              .init(mid0.y, mid1.y, mid2.y), out)
    
    return fma(.init(lhs0.x, lhs1.x, lhs2.x),
               .init(mid0.x, mid1.x, mid2.x), out)
}

/// Perform multiple dot products at once to maximize performance, with an optional zero-cost add.
@inlinable @inline(__always)
public func dotAdd(_ lhs0: simd_float2, _ mid0: simd_float2, rhs0: Float = 0,
                   _ lhs1: simd_float2, _ mid1: simd_float2, rhs1: Float = 0,
                   _ lhs2: simd_float2, _ mid2: simd_float2, rhs2: Float = 0,
                   _ lhs3: simd_float2, _ mid3: simd_float2, rhs3: Float = 0) -> simd_float4
{
    let out = fma(.init(lhs0.y, lhs1.y, lhs2.y, lhs3.y),
                  .init(mid0.y, mid1.y, mid2.y, mid3.y),
                  .init(rhs0,   rhs1,   rhs2,   rhs3))
    
    return fma(.init(lhs0.x, lhs1.x, lhs2.x, lhs3.x),
               .init(mid0.x, mid1.x, mid2.x, mid3.x), out)
}

/// Perform multiple dot products at once to maximize performance, with an optional zero-cost add.
@inlinable @inline(__always)
public func dotAdd(_ lhs0: simd_float3, _ mid0: simd_float3, rhs0: Float = 0,
                   _ lhs1: simd_float3, _ mid1: simd_float3, rhs1: Float = 0,
                   _ lhs2: simd_float3, _ mid2: simd_float3, rhs2: Float = 0,
                   _ lhs3: simd_float3, _ mid3: simd_float3, rhs3: Float = 0) -> simd_float4
{
    var out = fma(.init(lhs0.z, lhs1.z, lhs2.z, lhs3.z),
                  .init(mid0.z, mid1.z, mid2.z, mid3.z),
                  .init(rhs0,   rhs1,   rhs2,   rhs3))
    
    out = fma(.init(lhs0.y, lhs1.y, lhs2.y, lhs3.y),
              .init(mid0.y, mid1.y, mid2.y, mid3.y), out)
    
    return fma(.init(lhs0.x, lhs1.x, lhs2.x, lhs3.x),
               .init(mid0.x, mid1.x, mid2.x, mid3.x), out)
}

// MARK: - Transformation matrix creation

@inlinable @inline(__always)
public func matrix3x3_scale(sx: Float, sy: Float, sz: Float) -> simd_float3x3 {
    simd_float3x3(diagonal: .init(sx, sy, sz))
}

@inlinable @inline(__always)
public func matrix3x3_scale(_ s: simd_float3) -> simd_float3x3 {
    matrix3x3_scale(sx: s.x, sy: s.y, sz: s.z)
}

@inlinable @inline(__always)
public func matrix4x4_scale(sx: Float, sy: Float, sz: Float) -> simd_float4x4 {
    simd_float4x4(diagonal: .init(sx, sy, sz, 1))
}

@inlinable @inline(__always)
public func matrix4x4_scale(_ s: simd_float3) -> simd_float4x4 {
    matrix4x4_scale(sx: s.x, sy: s.y, sz: s.z)
}

@inlinable @inline(__always)
public func matrix4x4_translation(tx: Float, ty: Float, tz: Float) -> simd_float4x4 {
    simd_float4x4(
        .init(1, 0, 0, 0),
        .init(0, 1, 0, 0),
        .init(0, 0, 1, 0),
        .init(tx, ty, tx, 1)
    )
}

@inlinable @inline(__always)
public func matrix4x4_translation(_ t: simd_float3) -> simd_float4x4 {
    simd_float4x4(
        .init(1, 0, 0, 0),
        .init(0, 1, 0, 0),
        .init(0, 0, 1, 0),
        .init(t, 1)
    )
}

@inlinable @inline(__always)
public func matrix4x4_perspective(fovRadiansY: Float, aspect: Float, nearZ: Float = 0.001, farZ: Float = 1000) -> simd_float4x4 {
    let ys = 1 / tan(fovRadiansY * 0.5)
    let xs = ys / aspect
    
    return matrix4x4_perspective(xs: xs, ys: ys, nearZ: nearZ, farZ: farZ)
}

@inlinable @inline(__always)
public func matrix4x4_perspective(xs: Float, ys: Float, nearZ: Float, farZ: Float) -> simd_float4x4 {
    let zs = farZ / (nearZ - farZ)
    
    return simd_float4x4(
        .init(xs, 0, 0,  0),
        .init(0, ys, 0,  0),
        .init(0, 0, zs, -1),
        .init(0, 0, nearZ * zs, 0)
    )
}

public extension simd_float4x4 {
    
    @inlinable @inline(__always)
    init(rotation: simd_float3x3, translation: simd_float3) {
        self.init(
            .init(rotation[0], 0),
            .init(rotation[1], 0),
            .init(rotation[2], 0),
            .init(translation, 1)
        )
    }
    
    @inlinable @inline(__always)
    var upperLeft: simd_float3x3 {
        .init(
            simd_make_float3(self[0]),
            simd_make_float3(self[1]),
            simd_make_float3(self[2])
        )
    }
    
    @inlinable @inline(__always)
    var upperLeftTranspose: simd_float3x3 {
        .init(
            .init(self[0][0], self[1][0], self[2][0]),
            .init(self[0][1], self[1][1], self[2][1]),
            .init(self[0][2], self[1][2], self[2][2])
        )
    }
    
    @inlinable @inline(__always)
    func appendingTranslation(_ translation: simd_float3) -> simd_float4x4 {
        var output = self
        output[3] += simd_float4(translation, 0)
        return output
    }
    
    @inlinable @inline(__always)
    func replacingTranslation(with translation: simd_float3) -> simd_float4x4 {
        var output = self
        output[3] = simd_float4(translation, 1)
        return output
    }
    
    @inlinable @inline(__always)
    func prependingTranslation(_ translation: simd_float3) -> simd_float4x4 {
        var output = self
        output[3] = output * simd_float4(translation, 1)
        return output
    }
    
    @inlinable @inline(__always)
    var inverseRotationTranslation: simd_float4x4 {
        var output = simd_float4x4(
            .init(self[0][0], self[1][0], self[2][0], 0),
            .init(self[0][1], self[1][1], self[2][1], 0),
            .init(self[0][2], self[1][2], self[2][2], 0),
            -columns.3
        )
        
        var newLastColumn = unsafeBitCast(output, to: simd_float4x3.self)[2] * output[3][2]
        newLastColumn = fma(unsafeBitCast(output, to: simd_float4x3.self)[1],  output[3][1], newLastColumn)
        newLastColumn = fma(unsafeBitCast(output, to: simd_float4x3.self)[0],  output[3][0], newLastColumn)
        
        output.columns.3 = simd_float4(newLastColumn, 1)
        
        return output
    }
    
}

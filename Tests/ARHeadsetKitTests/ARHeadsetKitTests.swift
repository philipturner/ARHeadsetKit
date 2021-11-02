import XCTest
@testable import ARHeadsetKit

final class ARHeadsetKitTests: XCTestCase {
    func testExample() throws {
        let testArray = [Int](unsafeUninitializedCount: 5)
        XCTAssertEqual(testArray.count, 5, "Array initializer failed")
        
        let testRange = Range(CFRange(location: 0, length: 1))
        XCTAssertEqual(testRange.lowerBound, 0, "CFRange conversion failed")
        XCTAssertEqual(testRange.upperBound, 1, "CFRange conversion failed")
        
        XCTAssertEqual(roundUpToPowerOf2(7), 8, "Integer rounding utility failed")
        XCTAssertEqual(radiansToDegrees(0), 0, "Angle conversion utility failed")
        
        let testMatrix = simd_float4x4(rotation: matrix_identity_float3x3, translation: .zero)
        XCTAssertEqual(testMatrix          , matrix_identity_float4x4, "Matrix conversion failed (3x3 -> 4x4)")
        XCTAssertEqual(testMatrix.upperLeft, matrix_identity_float3x3, "Matrix conversion failed (4x4 -> 3x3)")
        
        let testFMA = fma(Float(0), simd_float4.zero, Float(0))
        XCTAssertEqual(testFMA, simd_float4.zero, "FMA overload failed")
        
        let testPackedVector = simd_packed_float3(simd_float3.zero)
        XCTAssertEqual(testPackedVector.unpacked, simd_float3.zero, "Packed vector conversion failed")
        
        let testBoolVector = simd_bool2(false, false)
        XCTAssertEqual(testBoolVector[0], false, "Boolean vector initializer failed")
    }
}

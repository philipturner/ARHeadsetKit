//
//  RayTracing.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/28/21.
//

import simd

public enum RayTracing {
    public struct Ray: Equatable {
        /// The point where the ray starts.
        public var origin: simd_float3
        /// A non-normalized vector pointing in the ray's direction.
        public var direction: simd_float3
        
        @inlinable @inline(__always)
        public init(origin: simd_float3, direction: simd_float3) {
            self.origin    = origin
            self.direction = direction
        }
    }
    
    /**
     A plane defined by the implicit equation `0 = n * (P - P0)`.
     */
    public typealias Plane = (point: simd_float3, normal: simd_float3)
    
    /**
     Intersects a ray direction with an origin at (0, 0, 0) with a plane.
     
     Use this instead of directly intersecting a ray whenever possible.
     */
    public static func getProgress(_ direction: simd_float3, onto plane: Plane) -> Float {
        let dotProducts = dotAdd(plane.normal, plane.point,
                                 plane.normal, direction)
        
        return dotProducts[0] / dotProducts[1]
    }
    
    /// Intersects a ray with a plane.
    public static func getProgress(_ ray: Ray, onto plane: Plane) -> Float {
        let adjustedPlane = Plane(plane.point - ray.origin, plane.normal)
        
        return getProgress(ray.direction, onto: adjustedPlane)
    }
    
    /**
     Projects a ray direction with an origin at (0, 0, 0) onto a plane.
     
     Use this instead of directly projecting a ray whenever possible.
     */
    public static func project(_ direction: simd_float3, onto plane: Plane) -> simd_float3 {
        direction * getProgress(direction, onto: plane)
    }
    
    /// Projects a ray onto a plane.
    public static func project(_ ray: Ray, onto plane: Plane) -> simd_float3 {
        ray.project(progress: getProgress(ray, onto: plane))
    }
}

public protocol RayTraceable {
    @inlinable func trace(ray worldSpaceRay: RayTracing.Ray) -> Float?
}

extension Array where Element: RayTraceable {
    
    @inlinable
    public func trace(ray worldSpaceRay: RayTracing.Ray) -> (elementID: Int, progress: Float)? {
        var elementID: Int = -1
        var minProgress: Float = .greatestFiniteMagnitude
        
        for i in 0..<count {
            let element = self[i]
            
            if let progress = element.trace(ray: worldSpaceRay), progress < minProgress {
                elementID = i
                minProgress = progress
            }
        }
        
        return minProgress < .greatestFiniteMagnitude ? (elementID, minProgress) : nil
    }
    
}



extension RayTracing.Ray {
    
    /// The location the ray reaches after traveling a given progress.
    @inlinable
    public func project(progress: Float) -> simd_float3 {
        fma(direction, progress, origin)
    }
    
    /**
     Whether the ray might intersect the model space's bounding box.
     
     - Returns:
        - false: The ray will never enter model space and intersect the tested object.
        - true: The ray might enter model space, but it not guaranteed to.
     */
    @inlinable
    public func passesInitialBoundingBoxTest() -> Bool {
        let origin_test = abs(origin) .>= 0.5
        
        let direction_sign = sign(direction)
        let point_away_test = direction_sign .== sign(origin)
        let direction_zero_test = direction_sign .== 0
        
        return !any(origin_test .& (point_away_test .| direction_zero_test))
    }
    
    /**
     Intersects a pair of model space bounding planes.
     
     - Precondition: Guarantee that ``passesInitialBoundingBoxTest()`` returns true. Also, the indexed component of the ray's direction must be nonzero.
     
     - Parameters:
        - index: The axis perpendicular to the two planes tested. If `index` is `0`, this function finds the intersections with the `x = -0.5` plane and/or the `x = 0.5` plane. For `1` and `2`, the function uses `y` and `z` instead of `x`.
     
     - Returns: After finding with one or two bounding planes the ray intersects,  returns the progress required to create the closest intersection.
     */
    @inlinable
    public func getBoundingCoordinatePlaneProgress(index: Int) -> Float {
        assert(passesInitialBoundingBoxTest())
        assert(direction[index] != 0)
        
        var planeCoord: Float
        
        if abs(origin[index]) >= 0.5 {
            assert(sign(origin[index]) != sign(direction[index]))
            
            planeCoord = copysign(0.5, origin[index])
        } else {
            planeCoord = copysign(0.5, direction[index])
        }
        
        return (planeCoord - origin[index]) / direction[index]
    }
    
    /**
     Performs ``getBoundingCoordinatePlaneProgress(index:)`` on all six planes at once.
     
     Use this instead of ``getBoundingCoordinatePlaneProgress(index:)``whenever possible.
     
     - Precondition: Guarantee that ``passesInitialBoundingBoxTest()`` returns true.
     
     - Returns: If any component of a ray's direction is zero, its corresponding component of the output will be [`Float.nan`](https://developer.apple.com/documentation/swift/float/1641209-nan).
     */
    @inlinable
    public func getBoundingCoordinatePlaneProgresses() -> simd_float3 {
        assert(passesInitialBoundingBoxTest())
        
        let signSources = direction.replacing(with: origin, where: abs(origin) .>= 0.5)
        let planeCoords = copysign(.init(repeating: 0.5), signSources)
        
        var output = (planeCoords - origin) / direction
        output.replace(with: .init(repeating: .nan), where: direction .== 0)
        return output
    }
    
    @inlinable @inline(__always)
    func finishRoundShapeProgress(_ b_half: Float, _ ac: Float) -> Float? {
        assert(passesInitialBoundingBoxTest())
        
        let discriminant_4th = fma(b_half, b_half, -ac)
        guard discriminant_4th >= 0 else { return nil }
        
        let discriminant_sqrt_half = sqrt(discriminant_4th)
        
        let upper_solution = -b_half + discriminant_sqrt_half
        guard upper_solution >= 0 else { return nil }
        
        let lower_solution = -b_half - discriminant_sqrt_half
        return lower_solution >= 0 ? lower_solution : upper_solution
    }
    
    @inlinable
    func getProgress(polyhedralShape shape: CentralShapeType) -> Float? {
        assert(passesInitialBoundingBoxTest())
        assert(shape.isPolyhedral)
        
        if shape == .cube {
            return getCentralCubeProgress()
        } else if shape == .squarePyramid {
            return getCentralSquarePyramidProgress()
        } else {
            assert(shape == .octahedron, "Did not update raytracing for new polyhedral shape \(String(shape))")
            return getCentralOctahedronProgress()
        }
    }
    
    @inlinable
    func getProgress(roundShape shape: CentralShapeType) -> Float? {
        assert(passesInitialBoundingBoxTest())
        assert(!shape.isPolyhedral)
        
        if shape == .cylinder {
            return getCentralCylinderProgress()
        } else if shape == .sphere {
            return getCentralSphereProgress()
        } else {
            assert(shape == .cone, "Did not update raytracing for new rounding shape \(String(shape))")
            return getCentralConeProgress()
        }
    }
    
}

import ARHeadsetKit

extension Cube {
    
    mutating func collide(location impactLocation: simd_float3,
                          direction: simd_float3, speed: Float)
    {
        assert(length(direction) > 0 && speed >= 0)
        
        // Masses are in kilograms
        let cubeMass: Float = 1
        let sphereMass: Float = 1
        
        // Radius of the sphere impacting the cube
        let radius: Float = 0.01
        
        // Surface normal at impact location
        let normal = findNormal(location: impactLocation)
        normalObject = getNormalObject(location: impactLocation, normal: normal)
        
        // Impact speed parallel to surface normal
        let sphereVelocity = speed * normalize(direction)
        let impactSpeed = dot(normal, sphereVelocity)
        
        // Reciprocal of moment of inertia (I)
        let cubeInverseI   = 6.0 / (cubeMass * sideLength * sideLength)
        let sphereInverseI = 3.0 / (2 * sphereMass * radius * radius)
        
        // Vectors pointing from impact location
        // to each object's center of mass
        let cubeCenterOffset = location - impactLocation
        let sphereCenterOffset = -normal * radius
        
        var inverseEffectiveMass = 1 / cubeMass + 1 / sphereMass
        
        do {
            func getComponent(inverseI: Float,
                              centerOffset: simd_float3) -> simd_float3
            {
                var output = cross(centerOffset, normal)
                output = inverseI * output
                return cross(centerOffset, output)
            }
            
            var sum = getComponent(inverseI: sphereInverseI,
                                   centerOffset: sphereCenterOffset)
            
            sum += getComponent(inverseI: cubeInverseI,
                                centerOffset: cubeCenterOffset)
            
            inverseEffectiveMass -= dot(normal, sum)
        }
        
        let impulse = 2 * impactSpeed / inverseEffectiveMass
        velocity = impulse / cubeMass * normal
        
        // Lowercase omega (ω) is the symbol
        // for angular velocity in physics.
        //
        // It is a vector, but it represents
        // rotation like a quaternion does.
        //
        var ω = impulse * normal
        ω = cross(cubeCenterOffset, ω)
        ω *= -cubeInverseI
        
        angularVelocity = simd_quatf(angle: length(ω),
                                     axis: normalize(ω))
        
        // To find the equations this function is based on, check out:
        // https://physics.stackexchange.com/questions/350658/calculate-force-between-rotating-objects
    }
    
    func findNormal(location: simd_float3) -> simd_float3 {
        let transform = object.worldToModelTransform
        let modelSpaceLocation4 = transform * simd_float4(location, 1)
        let modelSpaceLocation = simd_make_float3(modelSpaceLocation4)
        
        var axisIndex: Int
        
        if abs(modelSpaceLocation.x) > abs(modelSpaceLocation.y) {
            if abs(modelSpaceLocation.x) > abs(modelSpaceLocation.z) {
                axisIndex = 0
            } else {
                axisIndex = 2
            }
        } else {
            if abs(modelSpaceLocation.y) > abs(modelSpaceLocation.z) {
                axisIndex = 1
            } else {
                axisIndex = 2
            }
        }
        
        assert(abs(modelSpaceLocation[axisIndex].magnitude - 0.5) < 0.01)
        
        var modelSpaceNormal = simd_float3.zero
        modelSpaceNormal[axisIndex] = 2 * modelSpaceLocation[axisIndex]
        
        return object.orientation.act(modelSpaceNormal)
    }
    
}

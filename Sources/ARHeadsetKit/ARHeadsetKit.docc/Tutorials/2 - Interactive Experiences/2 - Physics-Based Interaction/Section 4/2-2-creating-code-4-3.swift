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

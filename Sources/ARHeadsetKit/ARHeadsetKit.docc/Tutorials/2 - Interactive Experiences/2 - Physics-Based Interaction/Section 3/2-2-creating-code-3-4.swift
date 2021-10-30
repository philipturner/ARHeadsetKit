import ARHeadsetKit

extension Cube {
    
    mutating func collide(location impactLocation: simd_float3,
                          direction: simd_float3, speed: Float)
    {
        assert(length(direction) > 0 && speed >= 0)
        
        velocity = speed * normalize(direction)
        angularVelocity = simd_quatf(angle: 2, axis: [0, 1, 0])
    }
    
    func findNormal(location: simd_float3) -> simd_float3 {
        let transform = object.worldToModelTransform
        let modelSpaceLocation4 = transform * simd_float4(location, 1)
        let modelSpaceLocation = simd_make_float3(modelSpaceLocation4)
    }
    
}

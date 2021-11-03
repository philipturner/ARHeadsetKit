import ARHeadsetKit

extension CubePicker {
    
    func updateResources() {
        if cubeIndex == nil {
            cubeIndex = getClosestCubeIndex()
        }
        
        func drawArrow(to target: simd_float3) {
            let transform = gameRenderer.cameraToWorldTransform
            let origin4 = transform * [0, 0, -0.3, 1]
            let origin = simd_make_float3(origin4)
            
            var direction = target - origin
            
            if length(direction) > 0 {
                direction = normalize(direction)
            } else {
                direction = [0, 1, 0]
            }
            
            typealias Ray = RayTracing.Ray
            let ray = Ray(origin: origin, direction: direction)
            
            gameRenderer.drawArrow(ray: ray, progress: 0.13)
        }
        
        if let cubeIndex = cubeIndex {
            let cube = cubeRenderer.cubes[cubeIndex]
            let object = cube.object!
            
            if !centralRenderer.shouldPresent(object: object) {
                drawArrow(to: cube.location)
            }
        }
    }
    
}

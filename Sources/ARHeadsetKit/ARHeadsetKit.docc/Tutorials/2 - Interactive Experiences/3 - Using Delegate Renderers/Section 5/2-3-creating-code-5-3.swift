import ARHeadsetKit

extension CubePicker {
    
    func updateResources() {
        if cubeIndex == nil {
            cubeIndex = getClosestCubeIndex()
        }
        
        func drawArrow(to target: simd_float3) {
        
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

import ARHeadsetKit

extension CubePicker {
    
    func updateResources() {
        if cubeIndex == nil {
            cubeIndex = getClosestCubeIndex()
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

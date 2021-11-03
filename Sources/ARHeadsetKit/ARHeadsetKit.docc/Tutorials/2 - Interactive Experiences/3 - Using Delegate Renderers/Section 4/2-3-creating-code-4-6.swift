import ARHeadsetKit

extension CubePicker {
    
    func updateResources() {
        if cubeIndex == nil {
            cubeIndex = getClosestCubeIndex()
        }
    }
    
}

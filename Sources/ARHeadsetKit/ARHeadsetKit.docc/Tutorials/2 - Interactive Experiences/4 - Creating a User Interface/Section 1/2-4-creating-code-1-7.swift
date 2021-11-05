import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
//        cubePicker.updateResources()
//
//        if let cubeIndex = cubePicker.cubeIndex {
//            cubes[cubeIndex].isRed = true
//        }
//
//        cubeRenderer.updateResources()
//
//        if let cubeIndex = cubePicker.cubeIndex {
//            cubes[cubeIndex].isRed = false
//
//            if cubes[cubeIndex].velocity != nil {
//                cubePicker.cubeIndex = nil
//            }
//        }
        
        gameInterface.updateResources()
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}

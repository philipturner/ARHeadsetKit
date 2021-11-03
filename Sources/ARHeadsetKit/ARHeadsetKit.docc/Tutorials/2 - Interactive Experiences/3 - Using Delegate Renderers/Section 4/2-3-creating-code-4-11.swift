import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
        cubePicker.updateResources()
        
        if let cubeIndex = cubePicker.cubeIndex {
            cubes[cubeIndex].isRed = true
        }
        
        cubeRenderer.updateResources()
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}

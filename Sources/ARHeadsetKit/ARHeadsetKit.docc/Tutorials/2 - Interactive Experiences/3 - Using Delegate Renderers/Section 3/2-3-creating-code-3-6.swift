import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
        cubes[0].isRed = true
        
        cubeRenderer.updateResources()
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}

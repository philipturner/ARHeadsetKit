import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
        cubeRenderer.updateResources()
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}

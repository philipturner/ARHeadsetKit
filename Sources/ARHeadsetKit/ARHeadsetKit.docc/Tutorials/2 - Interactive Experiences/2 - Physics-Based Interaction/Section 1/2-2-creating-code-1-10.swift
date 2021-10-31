import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
        if let ray = renderer.interactionRay,
           let _ = cube.trace(ray: ray) {
            cube.isHighlighted = true
        } else {
            cube.isHighlighted = false
        }
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}

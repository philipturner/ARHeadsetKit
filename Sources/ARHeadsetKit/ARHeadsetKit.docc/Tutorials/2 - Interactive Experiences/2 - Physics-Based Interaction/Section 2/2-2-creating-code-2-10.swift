import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
        if let ray = renderer.interactionRay,
           let progress = cube.trace(ray: ray) {
            cube.isHighlighted = true
        } else {
            cube.isHighlighted = false
        }
        
        cube.object = cube.getObject()
        
        cube.render(centralRenderer: centralRenderer)
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}

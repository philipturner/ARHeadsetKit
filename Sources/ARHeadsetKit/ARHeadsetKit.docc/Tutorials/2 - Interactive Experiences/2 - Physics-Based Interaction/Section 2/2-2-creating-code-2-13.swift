import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
        if let ray = renderer.interactionRay,
           let progress = cube.trace(ray: ray) {
            cube.isHighlighted = true
            
            if renderer.shortTappingScreen {
                let impactLocation = ray.project(progress: progress)
                
                // Speed is in meters per second
                cube.collide(location: impactLocation,
                             direction: ray.direction, speed: 0.2)
            }
        } else {
            cube.isHighlighted = false
        }
        
        cube.update()
        
        cube.render(centralRenderer: centralRenderer)
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}

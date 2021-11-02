import ARHeadsetKit

extension CubeRenderer {
    
    func updateResources() {
        if let ray = renderer.interactionRay,
           let progress = cube.trace(ray: ray) {
            cube.isHighlighted = true
            
            if renderer.shortTappingScreen {
                let impactLocation = ray.project(progress: progress)
                
                // Speed is in meters per second
                cube.collide(location: impactLocation,
                             direction: ray.direction, speed: 7)
            }
        } else {
            cube.isHighlighted = false
        }
        
        cube.update()
        
        cube.render(centralRenderer: centralRenderer)
    }
    
}

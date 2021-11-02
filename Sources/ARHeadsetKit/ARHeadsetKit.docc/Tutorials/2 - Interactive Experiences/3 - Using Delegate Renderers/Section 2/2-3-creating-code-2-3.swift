import ARHeadsetKit

extension CubeRenderer {
    
    func updateResources() {
        for i in 0..<cubes.count {
            cubes[i].isHighlighted = false
        }
        
        if let ray = renderer.interactionRay,
           let (elementID, progress) = cubes.trace(ray: ray) {
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

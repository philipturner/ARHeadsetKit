import ARHeadsetKit

extension CubeRenderer {
    
    func updateResources() {
        for i in 0..<cubes.count {
            cubes[i].isHighlighted = false
        }
        
        if let ray = renderer.interactionRay,
           let (elementID, progress) = cubes.trace(ray: ray) {
            cubes[elementID].isHighlighted = true
            
            if renderer.shortTappingScreen {
                let impactLocation = ray.project(progress: progress)
                
                // Speed is in meters per second
                cubes[elementID].collide(location: impactLocation,
                                         direction: ray.direction, speed: 7)
            }
        }
        
        for i in 0..<cubes.count {
            cubes[i].update()
            cubes[i].render(centralRenderer: centralRenderer)
        }
    }
    
}

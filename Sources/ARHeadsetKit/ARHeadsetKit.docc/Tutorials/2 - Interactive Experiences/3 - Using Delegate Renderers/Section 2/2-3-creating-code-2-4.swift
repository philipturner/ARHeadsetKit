import ARHeadsetKit

extension CubeRenderer {
    
    func updateResources() {
        for i in 0..<cubes.count {
            cubes[i].isHighlighted = false
        }
        
        if let ray = renderer.interactionRay,
           let (elementID, progress) = cubes.trace(ray: ray) {
        
        cube.update()
        
        cube.render(centralRenderer: centralRenderer)
    }
    
}

import ARHeadsetKit
import Metal

class GameRenderer {
    unowned let renderer: MainRenderer
    var cubePosition: simd_float3 = .zero
    
    required init(renderer: MainRenderer, library: MTLLibrary!) {
        self.renderer = renderer
    }
    
    func drawArrow(ray: RayTracing.Ray, progress: Float) {
        let tipStart = arrowEnd - 0.1 * arrowDirection
        let color = simd_float3(repeating: 0.8)
        
        if let tip = ARObject(roundShapeType: .cone,
                              bottomPosition: tipStart,
                              topPosition: arrowEnd,
                              diameter: 0.07,
                              
                              color: color)
        {
            centralRenderer.render(object: tip)
        }
        
        if let line = ARObject(roundShapeType: .cylinder,
                               bottomPosition: arrowStart,
                               topPosition: tipStart,
                               diameter: 0.05,
                               
                               color: color)
        {
            centralRenderer.render(object: line)
        }
    }
}

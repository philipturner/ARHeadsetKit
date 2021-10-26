import ARHeadsetKit
import Metal

class GameRenderer {
    unowned let renderer: MainRenderer
    var cubePosition: simd_float3 = .zero
    
    required init(renderer: MainRenderer, library: MTLLibrary!) {
        self.renderer = renderer
    }
    
    func drawArrow(center: simd_float3, orientation: simd_quatf) {
        let yAxis: simd_float3 = [0.0, 1.0, 0.0]
        let arrowDirection = orientation.act(yAxis)
        
        let arrowStart = center - 0.05 * arrowDirection
        let arrowEnd   = center + 0.15 * arrowDirection
        
        let tipStart = arrowEnd - 0.1 * arrowDirection
        
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

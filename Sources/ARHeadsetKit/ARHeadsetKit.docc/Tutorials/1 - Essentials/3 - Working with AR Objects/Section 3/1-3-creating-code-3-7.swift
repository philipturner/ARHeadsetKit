import ARHeadsetKit
import Metal

class MyRenderer: CustomRenderer {
    unowned let renderer: MainRenderer
    var numFrames: Int = 0
    
    required init(renderer: MainRenderer, library: MTLLibrary!) {
        self.renderer = renderer
    }
    
    func updateResources() {
        numFrames += 1
        
        let red:     simd_float3 = [1.00, 0.00, 0.00]
        let skyBlue: simd_float3 = [0.33, 0.75, 1.00]
        
        let coordinator = renderer.coordinator as! Coordinator
        let renderingRed = coordinator.renderingRed
        let color = renderingRed ? red : skyBlue
        
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
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
}

import ARHeadsetKit
import Metal

class MyRenderer: CustomRenderer {
    unowned let renderer: MainRenderer
    
    required init(renderer: MainRenderer, library: MTLLibrary!) {
        self.renderer = renderer
    }
    
    func updateResources() {
        let red:     simd_float3 = [1.00, 0.00, 0.00]
        let skyBlue: simd_float3 = [0.33, 0.75, 1.00]
        
        let coordinator = renderer.coordinator as! Coordinator
        let renderingRed = coordinator.renderingRed
        
        for shapeType in ARShapeType.allCases {
            let object = ARObject(shapeType: .cone,
                                  position: [0.0, 0.0, 0.0],
                                  scale: [0.2, 0.2, 0.2],
                                  
                                  color: renderingRed ? red : skyBlue)
            
            centralRenderer.render(object: object)
        }
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
}

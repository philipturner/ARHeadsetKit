import ARHeadsetKit
import Metal

class MyRenderer: CustomRenderer {
    unowned let renderer: MainRenderer
    var numFrames: Int = 0
    var objects: [ARObject] = []
    
    required init(renderer: MainRenderer, library: MTLLibrary!) {
        self.renderer = renderer
        
        generateObjects()
    }
    
    func updateResources() {
        numFrames += 1
        
        let red:     simd_float3 = [1.00, 0.00, 0.00]
        let skyBlue: simd_float3 = [0.33, 0.75, 1.00]
        
        let coordinator = renderer.coordinator as! Coordinator
        let renderingRed = coordinator.renderingRed
        let color = renderingRed ? red : skyBlue
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
    func generateObjects() {
        
    }
}

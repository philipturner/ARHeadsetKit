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
        func createShape(shapeType: ARShapeType,
                         position: simd_float3,
                         scale: simd_float3,
                         upDirection: simd_float3) -> ARObject
        {
            let yAxis: simd_float3 = [0.0, 1.0, 0.0]
            let orientation = simd_quatf(from: yAxis,
                                         to: normalize(upDirection))
            
            return ARObject(shapeType: shapeType,
                            position: position,
                            orientation: orientation,
                            scale: scale)
        }
        
        // User-selected color
        
        objects.append(createShape(
            shapeType: .squarePyramid,
            position:    [0.00, 0.00, -0.26],
            scale:       [0.08, 0.04,  0.04],
            upDirection: [1.00, 2.00,  6.00])
        )
        
        objects.append(createShape(
            shapeType: .cylinder,
            position:    [0.00, -0.12, -0.14],
            scale:       [0.10,  0.04,  0.10],
            upDirection: [0.00, -9.00,  1.00])
        )
    }
}

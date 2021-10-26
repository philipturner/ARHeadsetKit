import ARHeadsetKit

extension GameRenderer: CustomRenderer {
    
    func updateResources() {
        let mediumBlue: simd_float3 = [0.20, 0.50, 0.70]
        let lightBlue:  simd_float3 = [0.60, 0.80, 1.00]
        
        var object = ARObject(shapeType: .cube,
                              position: .zero,
                              scale: .init(repeating: 0.2),
                              
                              color: mediumBlue)
        
        if let interactionRay = renderer.interactionRay,
           object.trace(ray: interactionRay) != nil {
            object.color = simd_half3(lightBlue)
        }
    }
    
    func drawGeometry(renderEncoder: ARMetalRenderCommandEncoder) {
        
    }
    
}

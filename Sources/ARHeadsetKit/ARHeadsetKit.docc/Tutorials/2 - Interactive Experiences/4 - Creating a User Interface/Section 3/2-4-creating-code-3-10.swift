import ARHeadsetKit

extension GameInterface {
    
    func updateResources() {
        if buttons == nil {
            buttons = .init()
        }
        
        let resetButtonPos:  simd_float3 = [-0.12, 0, -0.3]
        let extendButtonPos: simd_float3 = [ 0.12, 0, -0.3]
        
        buttons[.resetButton ].setProperties(position: resetButtonPos)
        buttons[.extendButton].setProperties(position: extendButtonPos)
        
        
        
        var selectedButton: CachedParagraph?
        let renderer = gameRenderer.renderer
        
        if let interactionRay = renderer.interactionRay,
           let traceResult = buttons.trace(ray: interactionRay) {
            selectedButton = traceResult.elementID
        }
    }
    
}

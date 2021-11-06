import ARHeadsetKit

extension GameInterface {
    
    func updateResources() {
        if buttons == nil {
            buttons = .init()
        }
        
        
        
        var selectedButton: CachedParagraph?
        let renderer = gameRenderer.renderer
        
        if let interactionRay = renderer.interactionRay,
           let traceResult = buttons.trace(ray: interactionRay) {
            selectedButton = traceResult.elementID
        }
        
        if let selectedButton = selectedButton {
            buttons[selectedButton].isHighlighted = true
        }
        
        interfaceRenderer.render(elements: buttons.elements)
        
        if let selectedButton = selectedButton {
            buttons[selectedButton].isHighlighted = false
        }
    }
    
    func adjustInterface() {
        let cameraTransform = gameRenderer.cameraToWorldTransform
        let cameraDirection4 = -cameraTransform.columns.2
        let cameraDirection = simd_make_float3(cameraDirection4)
    }
    
}

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
    
}

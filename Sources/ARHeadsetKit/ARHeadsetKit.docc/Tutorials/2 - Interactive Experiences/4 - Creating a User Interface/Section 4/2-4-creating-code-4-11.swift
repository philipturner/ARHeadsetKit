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
        
        var rotation = simd_quatf(from: [0, 1, 0], to: cameraDirection)
        var axis = rotation.axis
        
        if rotation.angle == 0 {
            axis = [0, 1, 0]
        }
        
        func adjustButton(_ button: CachedParagraph, angleDegrees: Float) {
            let angleRadians = degreesToRadians(angleDegrees)
            rotation = simd_quatf(angle: angleRadians, axis: axis)
            
            let backwardDirection = rotation.act([0, 1, 0])
            let upDirection = cross(backwardDirection, axis)
            
            let orientation = ARInterfaceElement.createOrientation(
                forwardDirection: -backwardDirection,
                orthogonalUpDirection: upDirection
            )
            
            var position = gameRenderer.interfaceCenter
            position += backwardDirection * 0.7
            
            buttons[button].setProperties(position: position,
                                          orientation: orientation)
        }
    }
    
}

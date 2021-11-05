import ARHeadsetKit

extension GameInterface {
    
    func updateResources() {
        let segments: [ARParagraph.StringSegment] = [
            (string: "m", fontID: 0),
            (string: "m", fontID: 1),
            (string: "m", fontID: 2)
        ]
        
        let elementWidth: Float = 0.15
        
        let paragraph = InterfaceRenderer.createParagraph(
            stringSegments: segments,
            width: elementWidth,
            pixelSize: 0.25e-3
        )
        
        let characterGroups = paragraph.characterGroups
        let suggestedHeight = paragraph.suggestedHeight
        
        let element = ARInterfaceElement(
            position: [0, 0, -0.3],
            forwardDirection: [0, 0, 1],
            orthogonalUpDirection: [0, 1, 0],
            
            width: elementWidth,
            height: suggestedHeight,
            depth: 0.05, radius: 0.02,
            
            characterGroups: characterGroups
        )
        
        interfaceRenderer.render(element: element)
    }
    
}

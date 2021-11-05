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
    }
    
}

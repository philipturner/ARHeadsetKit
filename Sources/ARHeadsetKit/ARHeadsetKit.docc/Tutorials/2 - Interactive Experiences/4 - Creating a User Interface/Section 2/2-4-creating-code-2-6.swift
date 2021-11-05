/*
See LICENSE folder for this sample’s licensing information.
*/

import ARHeadsetKit

extension GameInterface: ARParagraphContainer {

    enum CachedParagraph: Int, ARParagraphListElement {
        case resetButton
        case extendButton
    }

}



fileprivate protocol GameInterfaceButton: ARParagraph { }

extension GameInterfaceButton {
    
    typealias CachedParagraph = GameInterface.CachedParagraph
    
    static var paragraphWidth: Float { 0.15 }
    static var pixelSize: Float { 0.25e-3 }
    static var radius: Float { 0.02 }
    
    static var parameters: Parameters {
        (stringSegments: [ (string: label, fontID: 2) ],
         width: paragraphWidth, pixelSize: pixelSize)
    }
    
    static func generateInterfaceElement(type: CachedParagraph) -> ARInterfaceElement {
        let paragraph = GameInterface.createParagraph(type)
        
        let width  = 2 * radius + paragraphWidth
        let height = 2 * radius + paragraph.suggestedHeight
    }
    
}

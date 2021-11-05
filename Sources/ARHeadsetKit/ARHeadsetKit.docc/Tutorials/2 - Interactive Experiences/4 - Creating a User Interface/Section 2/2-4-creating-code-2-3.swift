import ARHeadsetKit

extension GameInterface: ARParagraphContainer {
    
    enum CachedParagraph: Int, ARParagraphListElement {
        case resetButton
        case extendButton
    }
    
}



fileprivate protocol GameInterfaceButton: ARParagraph { }

extension GameInterfaceButton {
    
}

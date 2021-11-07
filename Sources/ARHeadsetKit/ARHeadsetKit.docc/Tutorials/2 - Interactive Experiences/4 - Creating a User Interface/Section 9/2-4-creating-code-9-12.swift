import ARHeadsetKit

extension GameInterface: ARParagraphContainer {
    
    enum CachedParagraph: Int, ARParagraphListElement {
        case resetButton
        case extendButton
            
        case reactionLabel
        
        var parameters: Parameters {
            switch self {
            case .resetButton:   return ResetButton.parameters
            case .extendButton:  return ExtendButton.parameters
            
            case .reactionLabel: return ReactionLabel.parameters
            }
        }
        
        var interfaceElement: ARInterfaceElement {
            switch self {
            case .resetButton:   return ResetButton  .generateInterfaceElement(type: self)
            case .extendButton:  return ExtendButton .generateInterfaceElement(type: self)
            
            case .reactionLabel: return ReactionLabel.generateInterfaceElement(type: self)
            }
        }
    }
    
    func updateReactionMessage() {
        if let message = reactionParams?.text,
           ReactionLabel.label != message
        {
            ReactionLabel.label = message
            
            let label = CachedParagraph.reactionLabel
            buttons[label] = label.interfaceElement
        }
    }
    
    struct ElementContainer: ARTraceableParagraphContainer {
        typealias CachedParagraph = GameInterface.CachedParagraph
        
        var elements = CachedParagraph.allCases.map{ $0.interfaceElement }
        
        subscript(index: CachedParagraph) -> ARInterfaceElement {
            get { elements[index.rawValue] }
            set { elements[index.rawValue] = newValue }
        }
        
        mutating func resetSize() {
            elements = CachedParagraph.allCases.map{ $0.interfaceElement }
        }
    }
    
}



fileprivate protocol GameInterfaceButton: ARParagraph { }

extension GameInterfaceButton {
    
    typealias CachedParagraph = GameInterface.CachedParagraph
    
    static var paragraphWidth: Float {
        if label == "Congratulations!" {
            return 0.30
        } else {
            return 0.15
        }
    }
    static var pixelSize: Float { 0.25e-3 }
    static var radius: Float { 0.02 }
    
    static var parameters: Parameters {
        (stringSegments: [ (string: label, fontID: 2) ],
         width: paragraphWidth, pixelSize: pixelSize)
    }
    
    static func generateInterfaceElement(type: CachedParagraph) -> ARInterfaceElement {
        var paragraph = GameInterface.createParagraph(type)
        
        let width  = 2 * radius + paragraphWidth
        let height = 2 * radius + paragraph.suggestedHeight
        
        let scale = GameInterface.interfaceScale
        InterfaceRenderer.scaleParagraph(&paragraph, scale: scale)
        
        
        
        let lightBlue  = simd_float3(0.6, 0.8, 1.0)
        let mediumBlue = simd_float3(0.3, 0.5, 0.7)
        let lightGray  = simd_float3(0.8, 0.8, 0.8)
        let mediumGray = simd_float3(0.5, 0.5, 0.5)
        
        return ARInterfaceElement(
            position: .zero, forwardDirection: [0, 0, 1], orthogonalUpDirection: [0, 1, 0],
            width: width * scale, height: height * scale,
            depth: 0.05  * scale, radius: radius * scale,
            
            highlightColor: [0.6, 0.8, 1.0], highlightOpacity: 1.0,
            surfaceColor:   [0.3, 0.5, 0.7], surfaceOpacity: 0.75,
            characterGroups: paragraph.characterGroups)
    }
    
}

fileprivate extension GameInterface {
    
    typealias Button = GameInterfaceButton
    
    enum ResetButton:   Button { static let label = "Reset" }
    enum ExtendButton:  Button { static let label = "Extend" }
        
    enum ReactionLabel: Button { static var label = "" }
    
}

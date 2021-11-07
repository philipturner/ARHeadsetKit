import ARHeadsetKit

class GameInterface: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    
    static var interfaceScale: Float = .nan
    
    var buttons: ElementContainer!
    var reactionParams: (text: String, location: simd_float3)?
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
        
        Self.cacheParagraphs()
    }
}

import ARHeadsetKit

class GameInterface: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    
    static var interfaceScale: Float = .nan
    
    var buttons: ElementContainer!
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
        
        Self.cacheParagraphs()
    }
}

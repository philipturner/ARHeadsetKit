import ARHeadsetKit

class GameInterface: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    
    var buttons: ElementContainer!
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
    }
}

import ARHeadsetKit

class GameInterface: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
    }
}

import ARHeadsetKit

class CubeRenderer: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    var cube: Cube!
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
    }
}

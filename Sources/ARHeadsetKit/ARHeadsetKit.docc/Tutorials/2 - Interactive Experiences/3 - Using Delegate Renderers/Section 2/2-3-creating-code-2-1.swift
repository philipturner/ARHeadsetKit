import ARHeadsetKit

class CubeRenderer: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    var cubes: [Cube] = []
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
    }
}

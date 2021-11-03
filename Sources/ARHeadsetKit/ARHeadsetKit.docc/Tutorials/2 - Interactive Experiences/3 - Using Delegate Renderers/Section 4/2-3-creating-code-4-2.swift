import ARHeadsetKit

class CubePicker: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    var cubeIndex: Int?
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
    }
}

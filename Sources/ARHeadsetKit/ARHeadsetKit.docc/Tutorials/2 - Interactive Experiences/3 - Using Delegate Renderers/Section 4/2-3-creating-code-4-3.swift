import ARHeadsetKit

class CubePicker: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    var cubeIndex: Int?
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
    }
    
    func getClosestCubeIndex() -> Int? {
        var closestIndex: Int?
        var closestDistance: Float = .greatestFiniteMagnitude
        var iterator = 0
    }
}

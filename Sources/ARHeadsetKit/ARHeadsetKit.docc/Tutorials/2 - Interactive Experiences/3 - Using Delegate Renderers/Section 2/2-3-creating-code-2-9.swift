import ARHeadsetKit

class CubeRenderer: DelegateGameRenderer {
    unowned let gameRenderer: GameRenderer
    var cubes: [Cube] = []
    
    required init(gameRenderer: GameRenderer) {
        self.gameRenderer = gameRenderer
        
        srand48(Int(Date().timeIntervalSince1970))
        
        for i in 0..<10 {
            func frand24() -> Float {
                Float(drand48())
            }
            
            var location: simd_float3
            print()
            print("Cube \(i): Searching for location")
        }
    }
}

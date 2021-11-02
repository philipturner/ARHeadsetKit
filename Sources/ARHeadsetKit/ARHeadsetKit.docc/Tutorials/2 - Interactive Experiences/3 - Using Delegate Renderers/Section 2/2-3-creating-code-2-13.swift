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
            
            repeat {
                location = simd_float3(
                    simd_mix(-0.3, 0.3, frand24()),
                    simd_mix(-0.3, 0.3, frand24()),
                    simd_mix(-0.6, 0.0, frand24())
                )
                
                print("Generated potential location")
            } while cubes.contains(where: { cube in
                distance(cube.location, location) < 0.21
            })
            
            var upDirection: simd_float3
            print("Cube \(i): Searching for up direction")
            
            repeat {
                upDirection = simd_float3(
                    simd_mix(-1, 1, frand24()),
                    simd_mix(-1, 1, frand24()),
                    simd_mix(-1, 1, frand24())
                )
                
                print("Generated potential up direction")
            } while length(upDirection) > 1
        }
    }
}

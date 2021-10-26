import ARHeadsetKit
import Metal

class GameRenderer {
    unowned let renderer: MainRenderer
    var cubePosition: simd_float3 = .zero
    
    required init(renderer: MainRenderer, library: MTLLibrary!) {
        self.renderer = renderer
    }
}

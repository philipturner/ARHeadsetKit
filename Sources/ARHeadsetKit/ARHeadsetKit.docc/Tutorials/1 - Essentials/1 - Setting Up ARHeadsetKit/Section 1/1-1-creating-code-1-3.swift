import ARHeadsetKit
import Metal

class MyRenderer {
    unowned let renderer: MainRenderer
    
    required init(renderer: MainRenderer, library: MTLLibrary!) {
        self.renderer = renderer
    }
}

import ARHeadsetKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, world!")
            .padding()
    }
}

class MyApp_MainRenderer: MainRenderer {
    override var makeCustomRenderer: CustomRendererInitializer {
        MyRenderer.init
    }
}

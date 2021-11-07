import ARHeadsetKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        let description = Coordinator.AppDescription(name: "My App")
        
        ARContentView<EmptySettingsView>()
            .environmentObject(Coordinator(appDescription: description))
    }
}

class MyApp_MainRenderer: MainRenderer {
    override var makeCustomRenderer: CustomRendererInitializer {
        GameRenderer.init
    }
}

class Coordinator: AppCoordinator {
    override var makeMainRenderer: MainRendererInitializer {
        MyApp_MainRenderer.init
    }
}

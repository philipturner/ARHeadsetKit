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
        MyRenderer.init
    }
}

class Coordinator: AppCoordinator {
    @Published var renderingRed: Bool = false
    
    override var makeMainRenderer: MainRendererInitializer {
        MyApp_MainRenderer.init
    }
}

struct SettingsView: CustomRenderingSettingsView {
    @ObservedObject var coordinator: Coordinator
    init(c: Coordinator) { coordinator = c }
    
    var body: some View {
        
    }
}

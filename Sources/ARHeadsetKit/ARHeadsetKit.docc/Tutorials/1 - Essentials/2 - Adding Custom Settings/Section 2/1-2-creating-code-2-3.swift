import ARHeadsetKit
import SwiftUI

struct ContentView: View {
    var body: some View {
        let description = Coordinator.AppDescription(name: "My App")
        
        ARContentView<SettingsView>()
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
    
    override func initializeCustomSettings(from storedSettings: [String : String]) {
        if let renderingRed_String = storedSettings["renderingRed"],
           let renderingRed_Bool = Bool(renderingRed_String) {
            renderingRed = renderingRed_Bool
        }
    }
}

struct SettingsView: CustomRenderingSettingsView {
    @ObservedObject var coordinator: Coordinator
    init(c: Coordinator) { coordinator = c }
    
    var body: some View {
        Toggle("Turn Objects Red", isOn: $coordinator.renderingRed)
    }
}

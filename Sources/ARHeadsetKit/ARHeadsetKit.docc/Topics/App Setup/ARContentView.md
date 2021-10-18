# ``ARHeadsetKit/ARContentView``

The entry-point view for using ARHeadsetKit.

## Overview

Pass a subclass of AppCoordinator as this view's environment object.

```Swift
@main
struct MyApp: App {
   var body: some Scene {
       WindowGroup {
           let description = Coordinator.AppDescription(name: "My App")
           
           ARContentView<SettingsView>()
               .environmentObject(Coordinator(appDescription: description))
       }
   }
}
```

## Topics

### Child Views

- ``CustomRenderingSettingsView``
- ``EmptySettingsView``

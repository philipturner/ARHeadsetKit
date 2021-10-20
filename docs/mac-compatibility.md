# Compatibility with macOS

ARHeadsetKit's [enhancements](enhancements-to-apple-frameworks.md) to Apple frameworks, Metal [utility functions](articles/metal-utility-functions.md), and CPU ray tracing API are available on macOS. To use ARHeadsetKit on macOS, you do not need to modify your source code. However, you must be cautious about updating documentation.

Documentation will not compile when you are on a macOS target. ALWAYS switch to an iOS build target before updating ARHeadsetKit's Swift package dependency and rebuilding documentation. If you do not do this, Xcode will not give you any indication that documentation failed to update. 

If your project can only compile for macOS, use an iOS sample project from ARHeadsetKit's tutorials instead of an iOS build target. You must update ARHeadsetKit in both your main macOS project and the iOS sample project before rebuilding documentation.

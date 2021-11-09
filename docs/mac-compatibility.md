# Compatibility with macOS

ARHeadsetKit's [enhancements](articles/enhancements-to-apple-frameworks.md) to Apple frameworks, Metal [utility functions](articles/metal-utility-functions.md), and CPU ray tracing API are available on macOS. To use ARHeadsetKit on macOS, you do not need to modify your source code. However, you must be cautious about updating documentation.

Documentation will not compile when you are on a macOS target. Always switch to an iOS build target before updating documentation as outlined in the [quick start](building-documentation.md#updating-documentation) guide. If you forget to do this, Xcode will not give you any indication that documentation failed to update. 

If your project can only compile for macOS, use the "ARHeadsetKit Documentation" project you created when first following the quick start guide. Update the Swift package dependency in both your main macOS project and the documentation project, as outlined in step 4 of the "Updating Documentation" section.

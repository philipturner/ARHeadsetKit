# Building ARHeadsetKit Documentation for the Documentation Viewer

Documentation automatically appears in the documentation viewer if ARHeadsetKit is configured as an Xcode framework and you pressed `Cmd + B` at least once. When using a Swift package, you must press `Ctrl + Cmd + Shift + D` to build documentation. Additionally, you must repeat this command every time you update ARHeadsetKit to a new version to access the most recent documentation and tutorials.

If ARHeadsetKit is configured as a Swift package, follow this procedure so that you don't have to press `Ctrl + Cmd + Shift + D`:
- Go to Build Settings
- In the search bar, type "build documentation"
- Set `Build Documentation during 'Build'` to `YES`
- Switch between "PROJECT" and "TARGETS" on the panel on the left and ensure that in both tabs, `Build documentation during 'build'` is set to `Yes`.

This setting means that every time you build or run your project, the documentation viewer refreshes ARHeadsetKit documentation. When ARHeadsetKit updates on GitHub, go to `Package Dependencies` -> `ARHeasetKit` -> `Update Package`. Press `Cmd + B` and new documentation will appear.

After building documentation successfully, read [this article](viewing-documentation.md) on how to view it.

# ARHeadsetKit (Beta)

Using a $5 Google Cardboard, the average person can now replicate Microsoft Hololens. Apps built with ARHeadsetKit are immersive AR headset experiences, simultaneously providing handheld AR alternatives. In just 30 lines of code, even someone without a background in Swift can work with AR.

ARHeadsetKit brings more than just AR experiences. It overhauls multiple iOS [and macOS](docs/mac-compatibility.md) frameworks with high-level [wrappers](docs/extensions-to-apple-frameworks.md) that maximize performance. [MTLLayeredBuffer](docs/articles/layered-buffer.md) lowers the barrier to learning Metal and managing GPGPU workflows. With easy-to-render AR objects and a CPU ray tracing API, ARHeadsetKit provides a unique environment for experimenting with 3D graphics. To learn more, check out [these articles](docs/article-list.md).

## Quick Start

Xcode 13 or higher is required for working with ARHeadsetKit, and an iOS device running at least iOS 14.0. You DO NOT need Google Cardboard. To get started, follow [this guide](docs/building-documentation.md) on how to run ARHeadsetKit's tutorials in Xcode.

If you are just starting out, ignore the sections below that deal with configuring ARHeadsetKit. Sample code from each tutorial's project files already has those settings configured. 

## Tutorial Series

There will be at least 9 tutorials for learning ARHeadsetKit, but only a few are finished. Here is each tutorial's current status:

- [ ] Ch. 1 - ARHeadsetKit Essentials
  - [x] Tutorial 1 - Configuring ARHeadsetKit (complete)
  - [x] Tutorial 2 - Adding Custom Settings (complete)
  - [ ] Tutorial 3 - Working with AR Objects
- [ ] Ch. 2 - Interactive Experiences
  - [ ] Tutorial 4 - Selecting Objects
  - [ ] Tutorial 5 - Using Delegate Renderers
  - [ ] Tutorial 6 - Creating a User Interface
- [ ] Ch. 3 - Unlocking Everything
  - [x] Tutorial 7 - Reconfiguring ARHeadsetKit (complete)
  - [ ] Tutorial 8 - Composing Custom Shaders
  - [ ] Tutorial 9 - Making Ray Tracing Functions

This repo will remain in the "beta" phase until every tutorial is finished. To learn when new tutorials are added, "watch" this GitHub repository or check it periodically. Also, please leave a star if you enjoy this repo's tutorials or [article series](docs/article-list.md) :-)

## How to Configure ARHeadsetKit from Scratch

In Xcode, go to File -> Project. In the template window that pops up, choose "App" under the "Application" section of iOS templates. This template is already selected by default. Do not use Xcode's AR template, because that creates a Storyboard. Xcode Storyboards (except for launch screens) have been made obsolete by [SwiftUI](https://developer.apple.com/xcode/swiftui) and will break ARHeadsetKit. Select "SwiftUI" instead of "Storyboard" under the interface options. Give your project a name, then click "Next" and finally "Create".

In the project navigator on the left of the editor, click the project folder at the very top, which has a blue Xcode logo next to it. You will open a list of various settings about your project. A section to the right of project navigator says `PROJECT` and `TARGETS`, with both words containing your project's name under them. Click your project's name under `TARGETS`. In a tab bar at the top, "General" will be highlighted and appear next to "Signing &amp; Capabilities". 

If you are only using ARHeadsetKit for its utility functions (such as [`MTLLayeredBuffer`](docs/articles/layered-buffer.md)), you do not need to modify the project's Info.plist. If your app provides an AR experience supported by ARHeadsetKit, follow [this guide](docs/property-list-keys.md) to configure your app's Info.plist correctly. Otherwise, your app will crash on launch.

## Choosing a Swift Package vs. an Xcode Framework

You can configure ARHeadsetKit in two ways: as a Swift package or an Xcode framework. A Swift package is easier to set up, and recommended unless you plan to create Metal shaders. An Xcode framework is required for importing ARHeadsetKit's Metal Shading Language [utility functions](docs/articles/metal-utility-functions.md) into your own shaders. In addition, the Xcode framework lets you use ARHeadsetKit's launch screen without breaking the file's connection to this GitHub repository.

To set up ARHeadsetKit as a Swift package, go to File -> Add Packages and paste this repository's URL. To set it up as an Xcode framework, follow ARHeadsetKit's tutorials in Xcode and reach the chapter "Unlocking Everything". The first part of that chapter, "Reconfiguring ARHeadsetKit", shows how to set up the Xcode framework.

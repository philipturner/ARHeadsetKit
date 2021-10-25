# ARHeadsetKit (Beta)

<p align="center">
  <img src="docs/images/google-cardboard-plus-ar.webp" alt="Google Cardboard plus AR" width="80%">
</p>
  
Using a $5 Google Cardboard, the average person can now replicate Microsoft Hololens. Apps built with ARHeadsetKit are immersive AR headset experiences, simultaneously providing handheld AR alternatives. In just 30 lines of code, even someone without a background in Swift can work with AR.

ARHeadsetKit brings more than just AR experiences. It overhauls multiple iOS [and macOS](docs/mac-compatibility.md) frameworks with high-level [wrappers](docs/extensions-to-apple-frameworks.md) that maximize performance. [MTLLayeredBuffer](docs/articles/layered-buffer.md) lowers the barrier to learning Metal and managing GPGPU workflows. With easy-to-render AR objects and a CPU ray tracing API, ARHeadsetKit provides a unique environment for experimenting with 3D graphics. To learn more, check out [these articles](docs/article-list.md).

## Quick Start

Xcode 13 or higher is required for working with ARHeadsetKit, and an iOS device running at least iOS 14.0. You DO NOT need Google Cardboard. To get started, follow [this guide](docs/building-documentation.md) on how to use ARHeadsetKit's tutorials.

If you are just starting out, ignore the sections below that deal with configuring ARHeadsetKit. Sample code from each tutorial's project files already has those settings configured.

## Tutorial Series

Learning ARHeadsetKit involves following tutorials hosted in Xcode, similar to Apple's [SwiftUI tutorials](https://developer.apple.com/tutorials/swiftui). There will be at least 11 tutorials, but only a few are finished so far. The status of each one is listed below:

- [x] Ch. 1 - Essentials (complete)
  - [x] Tutorial 1 - Setting Up ARHeadsetKit
  - [x] Tutorial 2 - Adding Custom Settings
  - [x] Tutorial 3 - Working with AR Objects
  - [x] Tutorial 4 - Alternative Rendering Modes
- [ ] Ch. 2 - Interactive Experiences
  - [ ] Tutorial 5 - Selecting Objects
  - [ ] Tutorial 6 - Using Delegate Renderers
  - [ ] Tutorial 7 - Creating a User Interface
- [ ] Ch. 3 - Unlocking Everything
  - [x] Tutorial 8 - Reconfiguring ARHeadsetKit (complete)
  - [ ] Tutorial 9 - Composing Custom Shaders
  - [ ] Tutorial 10 - Ray Tracing Functions
  - [ ] Tutorial 11 - The Essence of GPGPU

ARHeadsetKit will remain in the beta phase until every tutorial is finished. To learn when new tutorials are added, "watch" this GitHub repository or check it periodically. Also, please leave a star if you enjoy ARHeadsetKit's tutorials or [article series](docs/article-list.md) :-)

## How to Configure ARHeadsetKit from Scratch

Follow the "Creating an Xcode project" section of the [quick start](docs/building-documentation.md) guide. Name your project something other than "ARHeadsetKit Documentation". In the project navigator on the left of the Xcode window, click the folder at the very top with your project's name. The project settings will open, with a sidebar stating `PROJECT` and `TARGETS`. Click your project's name under `TARGETS`. In the tab bar at the top, ensure that "General" is selected.

If your app provides an AR experience supported by ARHeadsetKit, follow [this guide](docs/property-list-keys.md) to configure your app's Info.plist correctly. Otherwise, your app will crash on launch. You do not need to perform this step if you will only use ARHeadsetKit for its utility functions (such as [`MTLLayeredBuffer`](docs/articles/layered-buffer.md)).

## Choosing a Swift Package vs. an Xcode Framework

There are two options for adding a dependency to ARHeadsetKit: a Swift package or an Xcode framework. A Swift package is easier to set up, and recommended unless you plan to create Metal shaders. An Xcode framework is required for importing ARHeadsetKit's Metal Shading Language [utility functions](docs/articles/metal-utility-functions.md). In addition, the Xcode framework lets you use ARHeadsetKit's launch screen without breaking the file's connection to this GitHub repository.

To set up ARHeadsetKit as a Swift package, follow the "Adding the Swift package" section of the [quick start](docs/building-documentation.md) guide. To configure it as an Xcode framework, follow ARHeadsetKit's tutorials and reach "Unlocking Everything". The first tutorial in that chapter is a step-by-step guide to configuring the Xcode framework in a new or existing project.

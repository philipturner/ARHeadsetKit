# ARHeadsetKit

<p align="center">
  <img src="docs/images/google-cardboard-plus-ar.webp" alt="Google Cardboard plus AR" width="80%">
</p>

Using a $5 Google Cardboard, the average person can now replicate Microsoft Hololens. Apps built with ARHeadsetKit are immersive AR headset experiences, simultaneously providing handheld AR alternatives. In just 30 lines of code, even someone without a background in Swift can work with AR.

ARHeadsetKit brings more than just AR experiences. With easy-to-render AR objects and a CPU ray tracing API, ARHeadsetKit provides a unique environment for experimenting with 3D graphics. Its tutorial series simultaneously serves as an introduction to headset AR and iOS, using AR to make the learning process interactive. It can even be used for creating VR apps, when virtual objects cover someone's entire field of view.

For the story behind how ARHeadsetKit was created, check out [creating the first affordable AR headset](https://medium.com/@philipturnerAR/how-i-made-the-first-5-ar-headset-be876d78c41f). This framework also has a [YouTube video](https://youtu.be/iBITDQyy0rw) and an official [research paper](https://github.com/philipturner/arheadsetkit-research-paper).

## Quick Start

Xcode 13 or higher is required for working with ARHeadsetKit, and an iOS device running at least iOS 14. You DO NOT need Google Cardboard. To get started, follow [this guide](docs/building-documentation.md) on how to use ARHeadsetKit's tutorials.

If you are just starting out, ignore the sections below that deal with configuring ARHeadsetKit. Sample code from each tutorial's project files already has those settings configured.

## Tutorial Series

Learning ARHeadsetKit involves following tutorials hosted in Xcode, similar to Apple's [SwiftUI tutorials](https://developer.apple.com/tutorials/swiftui). ARHeadsetKit's [article series](docs/article-list.md) compliments its tutorials to provide a deeper understanding of how the framework works.

- Ch. 1 - Essentials
  - Tutorial 1 - Setting Up ARHeadsetKit
  - Tutorial 2 - Adding Custom Settings
  - Tutorial 3 - Working with AR Objects
  - Tutorial 4 - Alternative Rendering Modes
- Ch. 2 - Interactive Experiences
  - Tutorial 5 - Selecting Objects
  - Tutorial 6 - Physics-Based Interaction
  - Tutorial 7 - Using Delegate Renderers
  - Tutorial 8 - Creating a User Interface
- Ch. 3 - Unlocking Everything
  - Tutorial 9 - Reconfiguring ARHeadsetKit

## How to Configure ARHeadsetKit from Scratch

Follow the "Creating an Xcode project" section of the [quick start](docs/building-documentation.md) guide, but name your project something other than "ARHeadsetKit Documentation". In the project navigator on the left of the Xcode window, click the folder at the very top with your project's name. The project settings will open, with a sidebar stating `PROJECT` and `TARGETS`. Click your project's name under `TARGETS`. In the tab bar at the top, ensure that "General" is selected.

If your app provides an AR experience supported by ARHeadsetKit, follow [this guide](docs/property-list-keys.md) to configure your app's Info.plist correctly. Otherwise, your app will crash on launch. You do not need to perform this step if you will only use ARHeadsetKit for its utility functions (such as [`MTLLayeredBuffer`](docs/articles/layered-buffer.md)).

## Choosing a Swift Package vs. an Xcode Framework

There are two options for adding a dependency to ARHeadsetKit: a Swift package or an Xcode framework. A Swift package is easier to set up, and recommended unless you plan to create Metal shaders. An Xcode framework is required for importing ARHeadsetKit's Metal Shading Language utility functions. In addition, the Xcode framework lets you use ARHeadsetKit's launch screen without breaking the file's connection to this GitHub repository.

To set up ARHeadsetKit as a Swift package, follow the "Adding the Swift package" section of the [quick start](docs/building-documentation.md) guide. To configure it as an Xcode framework, follow ARHeadsetKit's tutorials and reach "Unlocking Everything". The first tutorial in that chapter is a step-by-step guide to configuring the Xcode framework in a new or existing project.




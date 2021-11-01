# Accessing ARHeadsetKit Documentation and Tutorials

Follow the steps below to view ARHeadsetKit's tutorials in the Xcode documentation viewer.

### Creating an Xcode project

1. In Xcode, go to File -> New -> Project.
1. Ensure you are under the "iOS" template section.
1. The "App" template is selected by default. Leave this template selected.
1. Click "Next". Enter "ARHeadsetKit Documentation" as the product's name.
1. Under "Team", select your Apple account.
1. Click "Next" and save the project.

If this is your first time using Xcode, perform the following steps to ensure the project can compile:

1. Connect your iPhone or iPad to your Mac.
1. At the top of the Xcode window, a simulator will be selected as the run destination. Change that to your device.
1. Press `Cmd + B`. No errors should appear in Xcode.

### Adding the Swift package

1. In the menu bar, go to File -> Add Packages. A window for searching Swift packages will pop up.
1. In the search bar on the top right, paste this link: https://github.com/philipturner/ARHeadsetKit
1. Click "Add Package" on the bottom right. Click "Add Package" again in the window that pops up.

### Building documentation

1. Press `Cmd + Ctrl + Shift + D`. The documentation viewer will pop up.
1. In the navigator on the left, there is a section titled "Workspace Documentation". "ARHeadsetKit Documentation" will appear underneath it, with a blue Xcode logo next to it.
1. Unravel the contents of "ARHeadsetKit Documentation" and click "Welcome to ARHeadsetKit".
1. Go to Chapter 1: Essentials. Click on "Configuring ARHeadsetKit".
1. A tutorial will pop up. Download the project files, which contain sample code. After practicing how to update documentation (shown below), proceed with the tutorial.

When first opening sample code from a tutorial, there may be an error with loading Swift packages. If that happens, close out of the project and open it a second time.

## Updating Documentation

Periodically, do the following to make sure ARHeadsetKit and its tutorials are up to date:

1. In the bottom left of the Xcode window, right-click "ARHeadsetKit" under "Package Dependencies".
1. Click "Update Package". In the top of the Xcode window, you will see tasks related to package loading in progress.
1. Once the package has finished updating, press `Ctrl + Cmd + Shift + D`.
1. If you are working on a project that uses ARHeadsetKit, go to that one and repeat steps 1&ndash;2.

## Going Further

To view documentation for a specific symbol while working on source code:
1. Right-click on any ARHeadsetKit type or function in your Swift source code.
1. Click "Quick Help".
1. In the popup, click "Open in Developer Documentation".

Xcode's documentation viewer only supports Swift code, not ARHeadsetKit's Metal utility functions. Metal code will only show documentation in the "Quick Help" panel.

> Note: The "Open in Developer Documentation" link may not appear for Swift types and functions when another Xcode project was opened recently. If that happens, restart Xcode and open just the project you intend to work on. After that, you may open others.

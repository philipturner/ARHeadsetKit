# Accessing ARHeadsetKit Documentation and Tutorials

Follow the steps below to view ARHeadsetKit's tutorials in the Xcode documentation viewer.

### Creating the Xcode project

1. In Xcode, go to File -> New -> Project.
1. Ensure you are under the "iOS" template section.
1. The "App" template is selected by default. Leave this template selected.
1. Click "Next". Enter "ARHeadsetKit Documentation" as the product's name.
1. Under "Team", select your account instead of "None". Click "Next" and save the project.

### Adding the Swift package

1. In the menu bar, go to File -> Add Packages. A window for searching Swift packages will pop up.
1. In the search bar on the top right, paste this link: https://github.com/philipturner/ARHeadsetKit
1. Click "Add Package" on the bottom right. Click "Add Package" again in the window that pops up.

### Building documentation

1. Press "Ctrl + Cmd + Shift + D". The documentation viewer will pop up.
1. In the navigator on the left, there is a section titled "Workspace Documentation". "ARHeadsetKit Documentation" will appear underneath it, with a blue Xcode logo next to it.
1. Unravel the contents of "ARHeadsetKit Documentation" and click "Welcome to ARHeadsetKit".
1. Go to Chapter 1: Essentials. Click on "Configuring ARHeadsetKit".
1. A tutorial will pop up. Download the "project files", which contain sample code. After practicing how to update documentation (shown below), proceed with the tutorial.

When first opening sample code from a tutorial, there may be an error with loading Swift packages. If that happens, close out of the project and open it a second time.

### Updating documentation

Periodically, do the following to make sure ARHeadsetKit and the tutorials are up to date:

1. In the bottom left of the Xcode window, right-click "ARHeadsetKit" under "Package Dependencies".
1. Click "Update Package". In the top of the Xcode window, you will see tasks related to package loading in progress.
1. Once the package has finished updating, press `Ctrl + Cmd + Shift + D`.
1. If you are working on a project that uses ARHeadsetKit, go to that one and repeat steps 1&ndash;2.

## See Also

To learn more about what ARHeadsetKit's documentation has to offer, read [this article](viewing-documentation.md).

# Required Property List Keys

Ensure you are in Project Settings -> TARGETS -> General. Configure the following options under "Deployment Info":
- iOS 14.0 or higher
- Check iPhone, check iPad, uncheck Mac
- Main Interface: Should be blank
- Device Orientation: Only "Portrait" should be checked
- Status Bar Style: "Default"
- Check "Hide status bar"
- Check "Requires full screen"
- Uncheck "Supports multiple windows"

Navigate to "Info" in the tab bar, which is to the right of "Resource Tags". Ensure the following keys are present in the property list and match the values described below:
- `Privacy - Camera Usage Description` - Can be any string. You can (but don't have to) use the string in the example below.
- `CADisableMinimumFrameDurationOnPhone` - This key does not appear automatically in Xcode 13.1. It minimizes the chance of frame rate drops on the iPhone 13 Pro/Pro Max. Change its type from `String` to `Boolean`, and set its value to `1` or `YES`.
- `Supported interface orientations` - Must include `Item 0: Portrait (bottom home button)` and nothing else.
- `Requires Full Screen` - Set to `YES`. The app assumes it is using full screen, and may produce undefined behavior otherwise.
- `Application Scene Manifest` - Set `Enable Multiple Windows` to `NO`.
- `Required device capabilities` - This is an array of keys. Add a key for `ARKit`.

The following keys are recommended to prevent the status bar from appearing:
- `View controller-based status bar appearance` - `NO`
- `Status bar is initially hidden` - `YES`

The following must be deleted:
- `Supported interface orientations` - Remove anything other than `Portrait (bottom home button)`.
- `Supported interface orientations (iPad)` - Remove this array, otherwise iPads will not use the orientations specified in `Supported interface orientations`.
- `Supported interface orientations (iPhone)` - Remove this array, otherwise iPhones will not use the orientations specified in `Supported interface orientations`.

## Example:
- Application Scene Manifest
    - Enable Multiple Windows: NO
- Requires Full Screen: YES
- View controller-based status bar appearance: NO
- Status bar initially hidden: YES
- Privacy - Camera Usage Description: "This application uses your device's camera to provide an augmented reality experience."
- Required device capabilities
    - Item 0: ARKit
- Supported interface orientations
    - Item 0: Portrait
- CADisableMinimumFrameDurationOnPhone (Boolean): 1

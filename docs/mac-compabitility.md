# Compatibility with macOS

ARHeadsetKit's [enhancements](enhancements-to-apple-frameworks.md) to Apple frameworks, Metal [utility functions](articles/metal-utility-functions.md), and CPU ray tracing API are available on macOS. To import ARHeadsetKit on macOS, configure it as an Xcode framework. Go to `Project Settings` -> `TARGETS` -> `General` -> `Frameworks, Libraries, and Embedded Content`. Remove "ARHeadsetKit" and replace it with "ARHeadsetKit_macOS". On all import statements in source code, import "ARHeadsetKit_macOS" instead of "ARHeadsetKit".

## Projects Targeting Both iOS and macOS

If a project shares code between an iOS and macOS app, create a separate target for each platform. Under `Frameworks, Libraries, and Embedded Content`, the iOS target must link to "ARHeadsetKit", while the macOS target links "ARHeadsetKit_macOS". Use the following conditional import statements in source code:

Swift:
```swift
#if os(macOS)
import ARHeadsetKit_macOS
#else
import ARHeadsetKit
#endif
```

Metal:
```metal
#if __METAL_MACOS__
#include <ARHeadsetKit_macOS/HEADER_NAME.h>
#else
#include <ARHeadsetKit/HEADER_NAME.h>
#endif
```

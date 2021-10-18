# CV.MetalTexture

A value-type wrapper around `CVMetalTexture`.

## Overview

[`CVMetalTexture`](https://developer.apple.com/documentation/corevideo/cvmetaltexture-q3g) is bridged differently than other CoreVideo and CoreText types. It is a typealias of [`CVBuffer`](https://developer.apple.com/documentation/corevideo/cvbuffer-nfm), so adding members directly to `CVMetalTexture` would add members to `CVBuffer`. To prevent circumvent this name collision, methods and properties of `CVMetalTexture` are added to a separate type.

## Topics

### Name Components

- ``CV``
- ``CV/MetalTexture``

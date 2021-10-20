# ``ARHeadsetKit/RayTracing/Ray``

A type passed into ray tracing functions.

## Overview

All ray-object intersections occur in a model space spanning one cubic meter. It is centered at (0, 0, 0), and reaches -0.5 and +0.5 in each direction. The intersected shape will always touch all six bounding planes.

## Topics

### Structure

- ``origin``
- ``direction``
- ``init(origin:direction:)``
- ``project(progress:)``

### Custom Function Building Blocks

- ``passesInitialBoundingBoxTest()``
- ``getBoundingCoordinatePlaneProgress(index:)``
- ``getBoundingCoordinatePlaneProgresses()``

### Polyhedral Shape Intersections

- ``transformedIntoBoundingBox(_:)``
- ``getCubeProgress()``
- ``getSquarePyramidProgress()``
- ``getOctahedronProgress()``

### Round Shape Intersections

- ``getSphereProgress()``
- ``getCylinderProgress()``
- ``getConeProgress()``
- ``getConeMiddleProgress(topY:)``
- ``getConeBaseProgress()``
- ``getTruncatedConeProgress(topScale:)``
- ``getTruncatedConeTopProgress(topScale:)``

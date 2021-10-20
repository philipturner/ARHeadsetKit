// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ARHeadsetKit",
    platforms: [
        .iOS(.v14),
        .macOS(.v11)
    ],
    products: [
        // Products define the executables and libraries a package produces, and make them visible to other packages.
        .library(
            name: "ARHeadsetKit",
            targets: ["ARHeadsetKit"]),
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
//        .package(name: "ExportDeviceKit", url: "./Packages/ExportDeviceKit", branch: "master"),
        .package(name: "DeviceKit", url: "https://github.com/devicekit/DeviceKit", branch: "master"),
        .package(name: "ZippyJSON", url: "https://github.com/michaeleisel/ZippyJSON", branch: "master"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .target(
            name: "ARHeadsetKit",
            dependencies: [
                .product(
                    name: "DeviceKit",
                    package: "DeviceKit",
                    condition: .when(platforms: [.iOS])),
                "ZippyJSON"
            ],
            exclude: [
                "Scene Reconstruction/Reconstruction/Mesh Reduction/ReduceSubmeshes.metallib"
            ],
            resources: [
                // User Settings
                .process("User Settings/Lens Distortion Correction/LensDistortionCorrection.metal"),
                
                // Scene Reconstruction
                .process("Scene Reconstruction/SceneRendering.metal"),
                .process("Scene Reconstruction/Scene Rendering (2D)/SceneRendering2D.metal"),
                
                .process("Scene Reconstruction/Reconstruction/Mesh Reduction/SceneMeshReduction.metal"),
                .process("Scene Reconstruction/Reconstruction/Sorting/First Sort/FirstSceneSort.metal"),
                .process("Scene Reconstruction/Reconstruction/Sorting/Second Sort/SecondSceneSort.metal"),
                .process("Scene Reconstruction/Reconstruction/Sorting/Third Sort/ThirdSceneSort.metal"),
                .process("Scene Reconstruction/Reconstruction/Sorting/Fourth Sort/FourthSceneSort.metal"),
                .process("Scene Reconstruction/Reconstruction/Duplicate Removal/SceneDuplicateRemoval.metal"),
                
                .process("Scene Reconstruction/Reconstruction/Mesh Matching/First Match/FirstSceneMeshMatch.metal"),
                .process("Scene Reconstruction/Reconstruction/Mesh Matching/Second Match/SecondSceneMeshMatch.metal"),
                .process("Scene Reconstruction/Reconstruction/Mesh Matching/Third Match/ThirdSceneMeshMatch.metal"),
                .process("Scene Reconstruction/Reconstruction/Texel Rasterization/SceneTexelRasterization.metal"),
                .process("Scene Reconstruction/Reconstruction/Texel Management/SceneTexelManagement.metal"),
                
                .process("Scene Reconstruction/Culling/SceneCulling.metal"),
                .process("Scene Reconstruction/Occlusion Testing/SceneOcclusionTesting.metal"),
                .process("Scene Reconstruction/Occlusion Testing/SceneColorUpdate.metal"),
                
                // Hand Reconstruction
                .process("Hand Reconstruction/Optical Flow Measurement/OpticalFlowMeasurement.metal"),
                .process("Hand Reconstruction/Detection/HandDetection.metal"),
                
                // Interface Rendering
                .process("Interface Rendering/AR Interface/Font Handle/SignedDistanceFieldCreation.metal"),
                .process("Interface Rendering/AR Interface/InterfacePreprocessing.metal"),
                .process("Interface Rendering/AR Interface/InterfaceRendering.metal"),
                .copy   ("Interface Rendering/AR Interface/InterfaceSurfaceMeshIndices.data"),
                
                // Central Rendering
                .process("Central Rendering/CentralRendering.metal")
            ]),
        .testTarget(
            name: "ARHeadsetKitTests",
            dependencies: ["ARHeadsetKit"]),
    ]
)

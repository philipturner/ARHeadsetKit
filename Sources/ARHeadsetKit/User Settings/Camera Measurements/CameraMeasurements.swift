//
//  CameraMeasurements.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/11/21.
//

#if !os(macOS)
import ARKit
import UIKit
import DeviceKit

@usableFromInline
final class CameraMeasurements: DelegateUserSettings {
    @usableFromInline unowned let userSettings: UserSettings
    
    enum FlyingPerspectiveAdjustMode {
        case none
        case move
        case start
    }
    
    var flyingPerspectiveAdjustMode: FlyingPerspectiveAdjustMode = .none
    
    var deviceSize: simd_double3
    var screenSize: simd_double2
    var wideCameraOffset: simd_double3
    
    @usableFromInline var imageResolution: CGSize
    var aspectRatio: Float
    var cameraToScreenAspectRatioMultiplier: Float
    var cameraSpaceScreenCenter: simd_double3
    
    @usableFromInline var cameraToWorldTransform = simd_float4x4(1)
    @usableFromInline var worldToCameraTransform = simd_float4x4(1)
    @usableFromInline var flyingPerspectiveToWorldTransform = simd_float4x4(1)
    @usableFromInline var worldToFlyingPerspectiveTransform = simd_float4x4(1)
    
    @usableFromInline var worldToScreenClipTransform = simd_float4x4(1)
    @usableFromInline var worldToHeadsetModeCullTransform = simd_float4x4(1)
    @usableFromInline var worldToLeftClipTransform = simd_float4x4(1)
    @usableFromInline var worldToRightClipTransform = simd_float4x4(1)
    
    @inlinable @inline(__always)
    var handheldEyePosition: simd_float3 {
        let usingFlyingMode = userSettings.renderer.usingFlyingMode
        return simd_make_float3(usingFlyingMode ? flyingPerspectiveToWorldTransform[3] : cameraToWorldTransform[3])
    }
    
    var flyingPerspectivePosition: simd_float3!
    var cameraSpaceRotationCenter = simd_float3.zero
    var cameraSpaceHeadPosition = simd_float3.zero
    @usableFromInline var interfaceCenter = simd_float3.zero
    @usableFromInline var leftEyePosition = simd_float3.zero
    @usableFromInline var rightEyePosition = simd_float3.zero
    
    @usableFromInline var cameraSpaceLeftEyePosition = simd_float3.zero
    @usableFromInline var cameraSpaceRightEyePosition = simd_float3.zero
    var cameraSpaceBetweenEyesPosition = simd_float3.zero
    @usableFromInline var cameraSpaceHeadsetModeCullOrigin = simd_float3.zero
    
    var headsetProjectionTransform: simd_float4x4!
    @usableFromInline var cameraToLeftClipTransform = simd_float4x4(1)
    @usableFromInline var cameraToRightClipTransform = simd_float4x4(1)
    @usableFromInline var cameraToHeadsetModeCullTransform = simd_float4x4(1)
    
    var cameraPlaneWidthSum: Double = 0
    var cameraPlaneWidthSampleCount: Int = -12
    var currentPixelWidth: Double = 0
    
    init(userSettings: UserSettings, library: MTLLibrary) {
        self.userSettings = userSettings
        
        imageResolution = ARWorldTrackingConfiguration.supportedVideoFormats.first!.imageResolution
        aspectRatio = Float(imageResolution.width / imageResolution.height)
        
        var device = Device.current
        let possibleDeviceSize = device.deviceSize
        
        let nativeBounds = UIScreen.main.nativeBounds
        let screenBounds = CGSize(width: nativeBounds.height, height: nativeBounds.width)
        cameraToScreenAspectRatioMultiplier = aspectRatio * Float(screenBounds.height / screenBounds.width)
        
        if possibleDeviceSize == nil, UIDevice.current.userInterfaceIdiom == .phone {
            var device: FutureDevice
            
            if screenBounds.width >= 2778 || screenBounds.height >= 1284 {
                device = .iPhone14ProMax
            } else if screenBounds.width >= 2532 || screenBounds.height >= 1170 {
                if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
                    device = .iPhone14Pro
                } else {
                    device = .iPhone14
                }
            } else {
                device = .iPhoneSE3
            }
            
            deviceSize = device.deviceSize
            screenSize = device.screenSize
            wideCameraOffset = device.wideCameraOffset
        } else {
            if let possibleDeviceSize = possibleDeviceSize {
                deviceSize = possibleDeviceSize
            } else {
                if screenBounds.width >= 2732 || screenBounds.height >= 2048 {
                    device = .iPadPro12Inch5
                } else if screenBounds.width >= 2388 || screenBounds.height >= 1668 {
                    device = .iPadPro11Inch3
                } else if screenBounds.width >= 2360 || screenBounds.height >= 1640 {
                    device = .iPadAir4
                } else if screenBounds.width >= 2266 || screenBounds.height < 1620 {
                    device = .iPadMini6
                } else {
                    device = .iPad9
                }
                
                deviceSize = device.deviceSize
            }
            
            screenSize = device.screenSize
            wideCameraOffset = device.wideCameraOffset
        }
        
        cameraSpaceScreenCenter = simd_double3(fma(simd_double2(deviceSize.x, deviceSize.y), [0.5, -0.5],
                                                   simd_double2(-wideCameraOffset.x, wideCameraOffset.y)), wideCameraOffset.z)
    }
}
#endif

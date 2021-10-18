//
//  DeviceMeasurementProvider.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/10/21.
//

import DeviceKit
import simd

public enum DeviceBackCameraPosition {
    case topLeft
    case bottomLeft
    case topRight
    case middleRight
    case bottomRight
}

public protocol DeviceMeasurementProvider {
    @inlinable var deviceSize: simd_double3! { get }
    @inlinable var screenSize: simd_double2! { get }
    @inlinable var isFullScreen: Bool! { get }
    
    @inlinable var wideCameraOffset: simd_double3! { get }
    @inlinable var wideCameraID: DeviceBackCameraPosition! { get }
}

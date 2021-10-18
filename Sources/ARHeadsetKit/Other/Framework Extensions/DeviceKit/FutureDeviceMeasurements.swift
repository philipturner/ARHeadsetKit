//
//  FutureDeviceMeasurements.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/10/21.
//

import DeviceKit
import simd

// Estimates of measurements for devices that may be
// released before the app updates to account for them

public enum FutureDevice: DeviceMeasurementProvider {
    case iPhone14
    // case iPhone14Max - waiting to implement until rumors are more concrete
    case iPhone14Pro
    case iPhone14ProMax
    case iPhoneSE3
    
    @inlinable
    public var closestDevice: Device {
        switch self {
        case .iPhone14:       return .iPhone13
        case .iPhone14Pro:    return .iPhone13Pro
        case .iPhone14ProMax: return .iPhone13ProMax
        case .iPhoneSE3:      return .iPhoneSE2
        }
    }
    
    @inlinable
    public var deviceSize: simd_double3! {
        switch self {
        case .iPhone14:       return 0.001 * [146.71, 71.52, 7.65]
        case .iPhone14Pro:    return 0.001 * [146.71, 71.52, 7.65]
        case .iPhone14ProMax: return 0.001 * [160.84, 78.07, 7.65]
        case .iPhoneSE3:      return 0.001 * [138.44, 67.27, 7.31]
        }
    }
    
    @inlinable
    public var screenSize: simd_double2! {
        switch self {
        case .iPhone14:       return 0.001 * [139.77, 64.58]
        case .iPhone14Pro:    return 0.001 * [139.77, 64.58]
        case .iPhone14ProMax: return 0.001 * [153.90, 71.13]
        case .iPhoneSE3:      return 0.001 * [104.05, 58.50]
        }
    }
    
    @inlinable
    public var isFullScreen: Bool! { true }
    
    @inlinable
    public var wideCameraOffset: simd_double3! {
        switch self {
        case .iPhone14:       return 0.001 * [24.24, 24.24, 6.33]
        case .iPhone14Pro:    return 0.001 * [31.35, 13.43, 7.27]
        case .iPhone14ProMax: return 0.001 * [31.35, 13.43, 7.27]
        case .iPhoneSE3:      return 0.001 * [10.24, 10.44, 5.31]
        }
    }
    
    @inlinable
    public var wideCameraID: DeviceBackCameraPosition! {
        switch self {
        case .iPhone14:       return .bottomRight
        case .iPhone14Pro:    return .bottomLeft
        case .iPhone14ProMax: return .bottomLeft
        case .iPhoneSE3:      return .topLeft
        }
    }
}

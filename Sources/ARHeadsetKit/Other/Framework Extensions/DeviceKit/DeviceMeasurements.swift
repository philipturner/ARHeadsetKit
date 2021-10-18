//
//  DeviceMeasurements.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/10/21.
//

import DeviceKit
import simd

extension Device: DeviceMeasurementProvider {
    
    // These measurements were calculated from schematics located at
    // https://developer.apple.com/accessories/Accessory-Design-Guidelines.pdf
    //
    // All measurements are in meters
    
    @inlinable
    public var deviceSize: simd_double3! {
        switch self {
        case .iPhone6s:       return 0.001 * [138.29, 67.12, 7.10]
        case .iPhone6sPlus:   return 0.001 * [158.22, 77.94, 7.30]
        case .iPhoneSE:       return 0.001 * [123.83, 58.57, 7.60]
        
        case .iPhone7:        return 0.001 * [138.29, 67.12, 7.10]
        case .iPhone7Plus:    return 0.001 * [158.22, 77.94, 7.30]
        
        case .iPhone8:        return 0.001 * [138.44, 67.27, 7.31]
        case .iPhone8Plus:    return 0.001 * [158.38, 78.10, 7.52]
        case .iPhoneX:        return 0.001 * [143.57, 70.94, 7.70]
        
        case .iPhoneXR:       return 0.001 * [150.91, 75.72, 8.32]
        case .iPhoneXS:       return 0.001 * [143.57, 70.94, 7.70]
        case .iPhoneXSMax:    return 0.001 * [157.53, 77.42, 7.70]
        case .iPodTouch7:     return 0.001 * [123.40, 58.57, 6.10]
        
        case .iPhone11:       return 0.001 * [150.91, 75.72, 8.32]
        case .iPhone11Pro:    return 0.001 * [143.99, 71.36, 8.10]
        case .iPhone11ProMax: return 0.001 * [157.95, 77.84, 8.10]
        case .iPhoneSE2:      return 0.001 * [138.44, 67.27, 7.31]
        
        case .iPhone12Mini:   return 0.001 * [131.50, 64.21, 7.39]
        case .iPhone12:       return 0.001 * [146.71, 71.52, 7.39]
        case .iPhone12Pro:    return 0.001 * [146.71, 71.52, 7.39]
        case .iPhone12ProMax: return 0.001 * [160.84, 78.07, 7.39]
            
        case .iPhone13Mini:   return 0.001 * [131.50, 64.21, 7.65]
        case .iPhone13:       return 0.001 * [146.71, 71.52, 7.65]
        case .iPhone13Pro:    return 0.001 * [146.71, 71.52, 7.65]
        case .iPhone13ProMax: return 0.001 * [160.84, 78.07, 7.65]
        
        case .iPadMini5:      return 0.001 * [203.16, 134.75, 6.10]
        case .iPadMini6:      return 0.001 * [195.40, 134.80, 6.30]
        
        case .iPad5, .iPad6:  return 0.001 * [240.00, 169.47, 7.50]
        case .iPad7, .iPad8:  return 0.001 * [250.59, 174.08, 7.50]
        case .iPad9:          return 0.001 * [250.59, 174.08, 7.50]
        
        case .iPadAir3:       return 0.001 * [250.59, 174.08, 6.10]
        case .iPadAir4:       return 0.001 * [247.64, 178.51, 6.123]
        
        case .iPadPro9Inch:   return 0.001 * [240.00, 169.47, 6.10]
        case .iPadPro10Inch:  return 0.001 * [250.59, 174.08, 6.10]
        case .iPadPro11Inch:  return 0.001 * [247.64, 178.52, 5.953]
        case .iPadPro11Inch2: return 0.001 * [247.64, 178.52, 5.953]
        case .iPadPro11Inch3: return 0.001 * [247.64, 178.52, 5.953]
        
        case .iPadPro12Inch:  return 0.001 * [305.69, 220.58, 6.95]
        case .iPadPro12Inch2: return 0.001 * [305.69, 220.58, 6.90]
        case .iPadPro12Inch3: return 0.001 * [280.66, 214.99, 5.908]
        case .iPadPro12Inch4: return 0.001 * [280.66, 214.98, 5.86]
        case .iPadPro12Inch5: return 0.001 * [280.66, 215.00, 6.44]
        
        default:              return nil
        }
    }
    
    @inlinable
    public var screenSize: simd_double2! {
        switch self {
        case .iPhone6s:       return 0.001 * [104.05, 58.50]
        case .iPhone6sPlus:   return 0.001 * [121.54, 68.36]
        case .iPhoneSE:       return 0.001 * [ 90.39, 51.70]
        
        case .iPhone7:        return 0.001 * [104.05, 58.50]
        case .iPhone7Plus:    return 0.001 * [121.54, 68.36]
        
        case .iPhone8:        return 0.001 * [104.05, 58.50]
        case .iPhone8Plus:    return 0.001 * [121.54, 68.36]
        case .iPhoneX:        return 0.001 * [135.75, 63.12]
        
        case .iPhoneXR:       return 0.001 * [139.78, 64.58]
        case .iPhoneXS:       return 0.001 * [135.75, 63.13]
        case .iPhoneXSMax:    return 0.001 * [149.71, 69.61]
        case .iPodTouch7:     return 0.001 * [ 88.61, 49.92]
        
        case .iPhone11:       return 0.001 * [139.78, 64.58]
        case .iPhone11Pro:    return 0.001 * [134.95, 62.33]
        case .iPhone11ProMax: return 0.001 * [148.91, 68.81]
        case .iPhoneSE2:      return 0.001 * [104.05, 58.50]
        
        case .iPhone12Mini:   return 0.001 * [124.96, 57.67]
        case .iPhone12:       return 0.001 * [139.77, 64.58]
        case .iPhone12Pro:    return 0.001 * [139.77, 64.58]
        case .iPhone12ProMax: return 0.001 * [153.90, 71.13]
            
        case .iPhone13Mini:   return 0.001 * [124.96, 57.67]
        case .iPhone13:       return 0.001 * [139.77, 64.58]
        case .iPhone13Pro:    return 0.001 * [139.77, 64.58]
        case .iPhone13ProMax: return 0.001 * [153.90, 71.13]
        
        case .iPadMini5:      return 0.001 * [160.74, 120.81]
        case .iPadMini6:      return 0.001 * [160.74, 120.81]
        
        case .iPad5, .iPad6:  return 0.001 * [196.47, 147.39]
        case .iPad7, .iPad8:  return 0.001 * [207.36, 155.52]
        case .iPad9:          return 0.001 * [207.36, 155.52]
        
        case .iPadAir3:       return 0.001 * [213.50, 160.13]
        case .iPadAir4:       return 0.001 * [227.56, 158.44]
        
        case .iPadPro9Inch:   return 0.001 * [203.11, 153.71]
        case .iPadPro10Inch:  return 0.001 * [213.50, 160.13]
        case .iPadPro11Inch:  return 0.001 * [230.25, 161.13]
        case .iPadPro11Inch2: return 0.001 * [230.25, 161.13]
        case .iPadPro11Inch3: return 0.001 * [230.25, 161.13]
        
        case .iPadPro12Inch:  return 0.001 * [262.27, 196.61]
        case .iPadPro12Inch2: return 0.001 * [262.27, 196.61]
        case .iPadPro12Inch3: return 0.001 * [263.27, 197.61]
        case .iPadPro12Inch4: return 0.001 * [262.27, 196.61]
        case .iPadPro12Inch5: return 0.001 * [262.27, 196.61]
        
        default:              return nil
        }
    }
    
    @inlinable
    public var isFullScreen: Bool! {
        switch self {
        case .iPhone6s, .iPhone6sPlus, .iPhoneSE,
             .iPhone7,  .iPhone7Plus,
             .iPhone8,  .iPhone8Plus,
             .iPodTouch7, .iPhoneSE2:
            return false
            
        case .iPhoneX, .iPhoneXR, .iPhoneXS, .iPhoneXSMax,
             .iPhone11, .iPhone11Pro, .iPhone11ProMax,
             .iPhone12Mini, .iPhone12, .iPhone12Pro, .iPhone12ProMax,
             .iPhone13Mini, .iPhone13, .iPhone13Pro, .iPhone13ProMax:
            return true
        
        case .iPadMini5, .iPadAir3,
             .iPad5, .iPad6, .iPad7, .iPad8, .iPad9,
             .iPadPro9Inch, .iPadPro10Inch, .iPadPro12Inch, .iPadPro12Inch2:
            return false
            
        case .iPadMini6, .iPadAir4,
             .iPadPro11Inch, .iPadPro11Inch2, .iPadPro11Inch3,
             .iPadPro12Inch3, .iPadPro12Inch4, .iPadPro12Inch5:
            return true
            
        default:
            return nil
        }
    }
    
    // Absolute value of offset from top left corner of the device's
    // bounding box in landscape mode, where z = 0 is the touchscreen
    
    @inlinable
    public var wideCameraOffset: simd_double3! {
        switch self {
        case .iPhone6s:       return 0.001 * [ 6.95, 13.38, 5.58]
        case .iPhone6sPlus:   return 0.001 * [ 7.27, 14.10, 5.65]
        case .iPhoneSE:       return 0.001 * [ 7.35,  9.28, 5.11]
        
        case .iPhone7:        return 0.001 * [10.17, 10.37, 5.58]
        case .iPhone7Plus:    return 0.001 * [10.47, 10.45, 5.65]
        
        case .iPhone8:        return 0.001 * [10.24, 10.44, 5.31]
        case .iPhone8Plus:    return 0.001 * [10.56, 10.60, 5.52]
        case .iPhoneX:        return 0.001 * [11.62, 11.62, 5.70]
        
        case .iPhoneXR:       return 0.001 * [12.28, 12.28, 6.85]
        case .iPhoneXS:       return 0.001 * [11.82, 11.82, 5.86]
        case .iPhoneXSMax:    return 0.001 * [11.82, 11.82, 5.86]
        case .iPodTouch7:     return 0.001 * [ 7.42,  7.43, 4.04]
        
        case .iPhone11:       return 0.001 * [12.48, 12.48, 6.60]
        case .iPhone11Pro:    return 0.001 * [12.04, 12.04, 5.91]
        case .iPhone11ProMax: return 0.001 * [12.04, 12.04, 5.91]
        case .iPhoneSE2:      return 0.001 * [10.24, 10.44, 5.31]
        
        case .iPhone12Mini:   return 0.001 * [24.95, 10.67, 5.01]
        case .iPhone12:       return 0.001 * [27.01, 12.73, 5.01]
        case .iPhone12Pro:    return 0.001 * [12.16, 12.16, 5.51]
        case .iPhone12ProMax: return 0.001 * [30.90, 13.43, 5.91]
            
        case .iPhone13Mini:   return 0.001 * [23.21, 23.21, 6.33]
        case .iPhone13:       return 0.001 * [24.24, 24.24, 6.33]
        case .iPhone13Pro:    return 0.001 * [31.35, 13.43, 7.27]
        case .iPhone13ProMax: return 0.001 * [31.35, 13.43, 7.27]
        
        case .iPadMini5:      return 0.001 * [10.23, 10.23, 2.83]
        case .iPadMini6:      return 0.001 * [10.23, 10.23, 2.83]
        
        case .iPad5, .iPad6:  return 0.001 * [11.68, 14.37, 4.23]
        case .iPad7, .iPad8:  return 0.001 * [11.66, 14.37, 4.23]
        case .iPad9:          return 0.001 * [11.66, 14.37, 4.23]
        
        case .iPadAir3:       return 0.001 * [10.23, 10.23, 2.80]
        case .iPadAir4:       return 0.001 * [12.70, 12.69, 6.18]
        
        case .iPadPro9Inch:   return 0.001 * [11.63, 11.64, 4.92]
        case .iPadPro10Inch:  return 0.001 * [10.23, 10.23, 3.98]
        case .iPadPro11Inch:  return 0.001 * [12.70, 12.70, 5.70]
        case .iPadPro11Inch2: return 0.001 * [25.11, 13.14, 5.12]
        case .iPadPro11Inch3: return 0.001 * [25.14, 13.12, 5.12]
        
        case .iPadPro12Inch:  return 0.001 * [11.63, 11.64, 4.55]
        case .iPadPro12Inch2: return 0.001 * [11.63, 11.63, 4.07]
        case .iPadPro12Inch3: return 0.001 * [12.70, 12.70, 6.81]
        case .iPadPro12Inch4: return 0.001 * [25.11, 13.14, 5.28]
        case .iPadPro12Inch5: return 0.001 * [25.14, 13.12, 5.77]
        
        default:              return nil
        }
    }
    
    @inlinable
    public var wideCameraID: DeviceBackCameraPosition! {
        switch self {
        case .iPhone6s, .iPhone6sPlus, .iPhoneSE,
             .iPhone7,  .iPhone7Plus,
             .iPhone8,  .iPhone8Plus, .iPhoneX,
             .iPhoneXR, .iPhoneXS,    .iPhoneXSMax,    .iPodTouch7,
             .iPhone11, .iPhone11Pro, .iPhone11ProMax, .iPhoneSE2,
             .iPhone12Pro:
            return .topLeft
        
        case .iPhone12Mini, .iPhone12, .iPhone12ProMax,
             .iPhone13Pro, .iPhone13ProMax:
            return .bottomLeft
        
        case .iPadMini5, .iPadMini6,
             .iPad5, .iPad6, .iPad7, .iPad8, .iPad9,
             .iPadAir3, .iPadAir4,
             .iPadPro9Inch,  .iPadPro10Inch,  .iPadPro11Inch,
             .iPadPro12Inch, .iPadPro12Inch2, .iPadPro12Inch3:
            return .topLeft
        
        case .iPadPro11Inch2, .iPadPro11Inch3,
             .iPadPro12Inch4, .iPadPro12Inch5:
            return .bottomLeft
        
        case .iPhone13Mini, .iPhone13:
            return .bottomRight
        
        default:
            return nil
        }
    }
    
}

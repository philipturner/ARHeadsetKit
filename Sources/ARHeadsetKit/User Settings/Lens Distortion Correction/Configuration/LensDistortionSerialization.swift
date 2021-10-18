//
//  LensDistortionSerialization.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/21/21.
//

import Foundation
import simd
import ZippyJSON

extension LensDistortionCorrector {
    
    struct StoredSettings: Codable, Equatable {
        var headsetFOV: Double // in degrees
        var viewportDiameter: Double // in meters
        
        enum CaseSize: Int, Codable {
            case none = 0
            case small = 1
            case large = 2
            
            var thickness: Double { // in meters
                switch self {
                case .none:  return 0
                case .small: return 0.001 * 1.5
                case .large: return 0.001 * 5.0
                }
            }
            
            var protrusionDepth: Double { // in meters
                switch self {
                case .none:  return 0
                case .small: return 0.001 * 1.0
                case .large: return 0.001 * 3.5
                }
            }
        }
        
        var caseSize: CaseSize
        var caseThickness: Double { caseSize.thickness }
        var caseProtrusionDepth: Double { caseSize.protrusionDepth }
        
        var eyeOffsetX: Double // in meters
        var eyeOffsetY: Double // in meters
        var eyeOffsetZ: Double // in meters
        
        var k1_green: Float // for green light
        var k2_green: Float // for green light
        var k1_proportions: simd_float2 // red and blue's k1 divided by green's k1
        
        // ARHeadsetKit's model for lens distortion correction starts with the
        // final position, then maps to a place on the intermediate texture.
        // Positions are "normalized" so that (0, 0) is the center of the texture,
        // Otherwise, (0, 0) would be the top left.
        //
        // "Original position" means the position on the intermediate texture
        // "Corrected position" means the location of the final texture
        //
        // let p_c = normalized corrected position
        // let r_c = distance of corrected position from center
        //
        // var p_o: normalized original position
        // var r_o: distance of original position from center
        //
        // let distortion = 1 + k1 * r_c^2 + k_2 * r_c^4
        // r_o = r_c * distortion
        // p_o = r_o * normalize(p_c)
        //
        // This model does not require any division or square roots,
        // although normalization is used in the example above just
        // to explain what everything means. This model requires
        // extremely few clock cycles to execute. In fact, most
        // time in the compute shader is spent on memory operations.
        //
        // Each color is distorted differently, so k1 and k2 must
        // be fine-tuned for each color. This process would work
        // best with an AR interface in headset mode, but that
        // interface won't be implemented for the foreseeable future.
        //
        // The sum of k1 and k2 happen to be the same for every color
        // when fine-tuned correctly. While k1 and k2 must be fine-tuned
        // for green, only the k1 coefficients need to be fine-tuned
        // for red and blue. The property below automatically calculates
        // k2 for red and blue, relying on the fact that k1 + k2 is
        // the same for every color.
        //
        // When k1 of blue is greater than the k1 of red and green,
        // blue always maps to an area closer to the center of
        // the final texture during lens distortion. This behavior
        // allows for a custom, optimized alternative to Apple's
        // rasterization_rate_map_decoder that is more than 2x faster.
        // To ensure the custom alternative works, k1 and k2 must be
        // constrained as follows:
        //
        // k1 (red) < k1 (green) < k1 (blue)
        // k2 (red) > k2 (green) > k2 (blue)
        
        var k2_proportions: simd_float2 { // red and blue's k2 divided by green's k2
            let k_sum = k1_green + k2_green
            let remaining_k = fma(k1_green, -k1_proportions, k_sum)
            return remaining_k * Float(simd_fast_recip(Double(k2_green)))
        }
        
        static let defaultSettings = Self(
            headsetFOV: 80.0,
            viewportDiameter: 0.001 * 58,
            
            caseSize: .small,
            eyeOffsetX: 0.001 * 31,
            eyeOffsetY: 0.001 * 34,
            eyeOffsetZ: 0.001 * 77,
            
            k1_green: 0.135,
            k2_green: 0.185,
            k1_proportions: [0.70, 1.31]
        )
        
        func eyePositionMatches(_ other: Self) -> Bool {
            caseThickness == other.caseThickness &&
            caseProtrusionDepth == other.caseProtrusionDepth &&
                
            eyeOffsetX == other.eyeOffsetX &&
            eyeOffsetY == other.eyeOffsetY &&
            eyeOffsetZ == other.eyeOffsetZ
        }
        
        func viewportMatches(_ other: Self) -> Bool {
            eyePositionMatches(other) &&
            viewportDiameter == other.viewportDiameter
        }
        
        func intermediateTextureMatches(_ other: Self) -> Bool {
            headsetFOV == other.headsetFOV &&
            viewportDiameter == other.viewportDiameter &&
                
            k1_green == other.k1_green && k2_green == other.k2_green &&
            k1_proportions == other.k1_proportions
        }
    }
    
    static func retrieveSettings() -> StoredSettings? {
        guard let jsonData = try? Data(contentsOf: settingsURL) else {
            return nil
        }
        
        do {
            return try ZippyJSONDecoder().decode(StoredSettings.self, from: jsonData)
        } catch {
            debugLabel { print("Error deserializing lens distortion settings: \(error.localizedDescription)") }
            return nil
        }
    }
    
    static func saveSettings(_ settings: StoredSettings) {
        var jsonData: Data
        
        do {
            jsonData = try JSONEncoder().encode(settings)
        } catch {
            debugLabel { print("Error serializing lens distortion settings: \(error.localizedDescription)") }
            return
        }
        
        try! jsonData.write(to: settingsURL, options: .atomic)
    }
    
    private static let settingsURL: URL = {
        var directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory.appendPathComponent("ARHeadsetKit/User Settings/Lens Distortion Correction", isDirectory: true)
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        
        return directory.appendingPathComponent("settings.json", isDirectory: false)
    }()
    
}

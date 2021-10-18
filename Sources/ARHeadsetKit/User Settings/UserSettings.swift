//
//  UserSettings.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 6/13/21.
//

import Metal
import ARKit

@usableFromInline
final class UserSettings: DelegateRenderer {
    public unowned let renderer: MainRenderer
    
    var savingSettings = false
    var shouldSaveSettings = false
    var storedSettings: StoredSettings
    
    @usableFromInline var cameraMeasurements: CameraMeasurements!
    var lensDistortionCorrector: LensDistortionCorrector!
    
    required public init(renderer: MainRenderer, library: MTLLibrary) {
        self.renderer = renderer
        
        storedSettings = Self.retrieveSettings(renderer: renderer) ?? .defaultSettings
        
        cameraMeasurements      = CameraMeasurements     (userSettings: self, library: library)
        lensDistortionCorrector = LensDistortionCorrector(userSettings: self, library: library)
    }
    
    deinit {
        lensDistortionCorrector = nil
    }
}

protocol DelegateUserSettings {
    var userSettings: UserSettings { get }
    init(userSettings: UserSettings, library: MTLLibrary)
}

extension DelegateUserSettings {
    var renderer: MainRenderer { userSettings.renderer }
    var device: MTLDevice { userSettings.device }
    var renderIndex: Int { userSettings.renderIndex }
    var usingVertexAmplification: Bool { renderer.usingVertexAmplification }
    
    var usingHeadsetMode: Bool { renderer.usingHeadsetMode }
    var usingFlyingMode: Bool { renderer.usingFlyingMode }
    
    var cameraMeasurements: CameraMeasurements { userSettings.cameraMeasurements }
    var lensDistortionCorrector: LensDistortionCorrector { userSettings.lensDistortionCorrector }
}

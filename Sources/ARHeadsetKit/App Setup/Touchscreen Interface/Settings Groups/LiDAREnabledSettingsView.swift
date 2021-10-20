//
//  LiDAREnabledSettingsView.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/23/21.
//

#if !os(macOS)
import SwiftUI

struct LiDAREnabledSettings {
    enum Handedness: Int, Codable {
        case none = 0
        case left = 1
        case right = 2
    }
    
    var allowingSceneReconstruction: Bool
    var allowingHandReconstruction: Bool
    
    var handheldHandedness: Handedness
    var headsetHandedness: Handedness
    
    init(_ storedSettings: UserSettings.StoredSettings) {
        allowingSceneReconstruction = storedSettings.allowingSceneReconstruction
        allowingHandReconstruction  = storedSettings.allowingHandReconstruction
        handheldHandedness          = storedSettings.handheldHandedness
        headsetHandedness           = storedSettings.headsetHandedness
    }
}

struct LiDAREnabledSettingsView<Coordinator: AppCoordinator>: View {
    @ObservedObject var coordinator: Coordinator
    
    typealias Handedness = LiDAREnabledSettings.Handedness
    
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $coordinator.lidarEnabledSettings.allowingSceneReconstruction) {
                Text("Scene Reconstruction")
            }
            
            Toggle(isOn: $coordinator.lidarEnabledSettings.allowingHandReconstruction) {
                Text("Hand Reconstruction")
            }
            
            if coordinator.lidarEnabledSettings.allowingHandReconstruction {
                VStack {
                    Text("Choose On-Screen Hand")
                }
                .frame(maxWidth: UIScreen.main.bounds.width, alignment: .center)
                
                Picker("Handedness", selection: $coordinator.lidarEnabledSettings.handheldHandedness) {
                    Text("Left").tag(Handedness.left)
                    Text("Auto").tag(Handedness.none)
                    Text("Right").tag(Handedness.right)
                }
                .pickerStyle(SegmentedPickerStyle())
                
                Text("""
                The hand you will use to interact with virtual objects\(UIDevice.current.userInterfaceIdiom == .phone ? " when not in headset mode" : ""). Selecting "auto" will automatically guess handedness, but reduce hand reconstruction quality.\(UIDevice.current.userInterfaceIdiom == .phone ? " This will be overriden with \"left\" in headset mode." : "")
                """)
                    .font(.caption)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif

//
//  InteractionSettingsView.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/23/21.
//

#if !os(macOS)
import SwiftUI

struct InteractionSettings {
    var canHideSettingsIcon: Bool
    var usingHandForSelection: Bool
    var showingHandPosition: Bool
    
    init(_ storedSettings: UserSettings.StoredSettings) {
        canHideSettingsIcon   = storedSettings.canHideSettingsIcon
        usingHandForSelection = storedSettings.usingHandForSelection
        showingHandPosition   = storedSettings.showingHandPosition
    }
}

struct InteractionSettingsView<Coordinator: AppCoordinator>: View {
    @ObservedObject var coordinator: Coordinator
    
    var body: some View {
        VStack(alignment: .leading) {
            Toggle(isOn: $coordinator.interactionSettings.canHideSettingsIcon) {
                Text("Hide Settings Icon")
            }
            
            Toggle(isOn: $coordinator.interactionSettings.usingHandForSelection) {
                Text("Use Hand for Selection")
            }
            
            Text("""
            When this feature is enabled, use your on-screen hand to select virtual objects. Otherwise, point your device's back camera at virtual objects to select them.
            """)
                .font(.caption)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
#endif

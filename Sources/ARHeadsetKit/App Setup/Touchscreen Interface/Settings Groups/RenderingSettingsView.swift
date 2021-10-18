//
//  RenderingSettingsView.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/23/21.
//

import SwiftUI

struct RenderingSettings {
    var usingHeadsetMode: Bool
    var renderingViewSeparator: Bool
    var usingFlyingMode: Bool = false
    var interfaceScale: Float
    
    init(_ storedSettings: UserSettings.StoredSettings) {
        usingHeadsetMode       = storedSettings.usingHeadsetMode
        renderingViewSeparator = storedSettings.renderingViewSeparator
        interfaceScale         = storedSettings.interfaceScale
    }
}

public protocol CustomRenderingSettingsView: View {
    associatedtype Coordinator: AppCoordinator
    var coordinator: Coordinator { get }
    @inlinable init(c: Coordinator)
}

/// A placeholder for a custom appearance settings view.
public struct EmptySettingsView: CustomRenderingSettingsView {
    @ObservedObject public var coordinator: AppCoordinator
    @inlinable public init(c: Coordinator) { coordinator = c }
    
    public var body: some View {
        EmptyView()
    }
}

struct RenderingSettingsView<CustomSettingsView: CustomRenderingSettingsView>: View {
    typealias Coordinator = CustomSettingsView.Coordinator
    @ObservedObject var coordinator: Coordinator
    
    var body: some View {
        VStack(alignment: .center) {
            NavigationLink(destination: AppearanceSettingsView(coordinator: coordinator)) {
                Text("Customize Appearance")
            }
            
            if UIDevice.current.userInterfaceIdiom == .phone {
                Toggle(isOn: $coordinator.renderingSettings.usingHeadsetMode) {
                    Text("Headset Mode")
                }
                
                if coordinator.renderingSettings.usingHeadsetMode {
                    Toggle(isOn: $coordinator.renderingSettings.renderingViewSeparator) {
                        Text("Show View Separator")
                    }
                    
                    NavigationLink(destination: HeadsetTutorialView<Coordinator>(coordinator: coordinator)) {
                        Text("How to Use Google Cardboard")
                    }
                }
            }
            
            Toggle(isOn: $coordinator.renderingSettings.usingFlyingMode) {
                Text("Flying Mode")
            }
            
            if coordinator.renderingSettings.usingFlyingMode {
                NavigationLink(destination: FlyingTutorialView<Coordinator>(coordinator: coordinator)) {
                    Text("How to Use Flying Mode")
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    private struct AppearanceSettingsView: View {
        @ObservedObject var coordinator: Coordinator
        
        var body: some View {
            VStack(alignment: .center) {
                VStack {
                    Text("Control Interface Size")
                }
                .frame(maxWidth: UIScreen.main.bounds.width, alignment: .center)
                
                HStack {
                    Slider(value: $coordinator.renderingSettings.interfaceScale, in: 0.20...2.00)
                    
                    Text("\(Int(coordinator.renderingSettings.interfaceScale * 100))%")
                }
                
                CustomSettingsView(c: coordinator)
            }
            .padding(20)
            .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

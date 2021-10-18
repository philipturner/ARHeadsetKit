//
//  ARContentView.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 9/25/21.
//

import SwiftUI
import MetalKit

public struct ARContentView<CustomSettingsView: CustomRenderingSettingsView> {
    @inlinable public init() { }
    
    public func environmentObject(_ coordinator: CustomSettingsView.Coordinator) -> some View {
        InternalView(coordinator: coordinator)
    }
    
    private struct InternalView: View {
        var coordinator: CustomSettingsView.Coordinator
        
        var body: some View {
            ZStack {
                ARDisplayView<CustomSettingsView.Coordinator>(coordinator: coordinator)
                
                TouchscreenInterfaceView<CustomSettingsView>(coordinator: coordinator)
            }
            .ignoresSafeArea(.all)
        }
    }
}

struct ARDisplayView<Coordinator: AppCoordinator>: View {
    @ObservedObject var coordinator: Coordinator
    
    var body: some View {
        ZStack {
            let bounds = UIScreen.main.bounds
            
            MetalView(coordinator: coordinator)
                .disabled(false)
                .frame(width: bounds.height, height: bounds.width)
                .rotationEffect(.degrees(90))
                .position(x: bounds.width * 0.5, y: bounds.height * 0.5)
            
            HeadsetViewSeparator<Coordinator>(coordinator: coordinator)
        }
    }
    
    private struct MetalView: UIViewRepresentable {
        @ObservedObject var coordinator: Coordinator
        
        func makeCoordinator() -> Coordinator { coordinator }
        
        func makeUIView(context: Context) -> MTKView { context.coordinator.view }
        func updateUIView(_ uiView: MTKView, context: Context) { }
    }
}

struct TouchscreenInterfaceView<CustomSettingsView: CustomRenderingSettingsView>: View {
    typealias Coordinator = CustomSettingsView.Coordinator
    @ObservedObject var coordinator: Coordinator
    
    var body: some View {
        ZStack {
            SettingsIconView<Coordinator>(coordinator: coordinator)
            
            MainSettingsView<CustomSettingsView>(coordinator: coordinator)
            
            AppTutorialView<Coordinator>(coordinator: coordinator)
        }
    }
}

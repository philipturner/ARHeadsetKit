//
//  SettingsIconView.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/22/21.
//

import SwiftUI

struct SettingsIconView<Coordinator: AppCoordinator>: View {
    @ObservedObject var coordinator: Coordinator
    
    var body: some View {
        ZStack {
            let offset: CGFloat = 50
            let hitboxRadius: CGFloat = 50
            
            Image(systemName: "gear")
                .imageScale(.large)
                .position(x: offset, y: offset)
                .foregroundColor(.white)
                .colorMultiply(coordinator.settingsIconIsHidden ? .clear : .white)
                .opacity(0.7)
                
                .animation(.easeInOut(duration: {
                    if coordinator.shouldImmediatelyHideSettingsIcon {
                        coordinator.shouldImmediatelyHideSettingsIcon = false
                        return 0
                    } else {
                        return 0.4
                    }
                }()))
            
            Path(ellipseIn: CGRect(x: offset - hitboxRadius,
                                   y: offset - hitboxRadius,
                                   width:  hitboxRadius * 2,
                                   height: hitboxRadius * 2))
                .fill(Color.white.opacity(1e-5))
                .onTapGesture {
                    if coordinator.settingsIconIsHidden {
                        coordinator.settingsIconIsHidden = false
                    } else if !coordinator.settingsAreShown {
                        coordinator.settingsAreShown = true
                    }
                }
        }
    }
}

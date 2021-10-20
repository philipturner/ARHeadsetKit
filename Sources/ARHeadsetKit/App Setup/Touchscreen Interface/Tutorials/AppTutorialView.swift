//
//  AppTutorialView.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/24/21.
//

#if !os(macOS)
import SwiftUI

struct AppTutorialCheck: Equatable {
    var check1 = false
    var check2 = false
    var check3 = false
}

struct AppTutorialView<Coordinator: AppCoordinator>: View {
    @ObservedObject var coordinator: Coordinator
    
    static func makeSeparatedParagraphs(around middle: String?, start: [String] = [], end: [String] = []) -> String {
        let paragraphs = start + [middle?.split(separator: "\n") ?? []] + end
        
        return paragraphs.reduce(into: "") {
            $0 += "\n\($1)"
        }
    }
    
    var body: some View {
        VStack {
            
        }
        .fullScreenCover(isPresented: $coordinator.showingAppTutorial) {
            ScrollView(.vertical, showsIndicators: true) {
                let description = coordinator.appDescription
                
                VStack {
                    
                }
                .frame(height: 50)
                
                VStack {
                    VStack {
                        Text(coordinator.appDescription.name)
                            .font(.title)
                    }
                    
                    VStack {
                        let start = description.summary?.split(separator: "\n").map{ String($0) } ?? []
                        
                        let end = [
                            "The interactive controls used in this app differ greatly from most other interactions on iOS. PLEASE THOROUGHLY READ THE FOLLOWING TUTORIAL BEFORE USING THIS APP."
                        ]
                        
                        Text((start + end).reduce(into: "") {
                            $0 += "\n\($1)\n"
                        })
                    }
                    
                    VStack {
                        Text("Using \(description.name)")
                            .font(.title2)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("""
                        
                        To access the in-app settings panel, tap the settings icon in the top left corner of your device's screen. Since the settings icon may interfere with your AR experience, you can opt to hide it. It will automatically hide but reappear whenever you tap in the top left corner of your device's screen.
                        
                        If you have Google Cardboard, you can turn your iPhone into an AR headset that renders your surroundings in VR, based on images acquired using your device's camera. In this app, Google Cardboard is used differently than with most VR experiences. After activating "Headset Mode" in the settings panel, you will be able to read a tutorial on how to properly use Google Cardboard with this app.
                        """)
                        
                        let start = [
                            "In this guide, the hand that touches your device's screen will be referred to as the \"clicking hand.\" The hand seen in your display will be referred to as the \"on-screen hand.\"",
                            
                            "When touching the screen with your clicking hand, all touches will be treated the same, regardless of their location (except when touching the settings icon). Essentially, you're using a touch on the screen like clicking a mouse button. This may not feel intuitive since most other experiences on iOS use the location of your touch.",
                            
                            "You can highlight elements in the \(description.controlInterfaceColor) control interface by moving your on-screen hand over them. After a control is highlighted, use it by tapping anywhere on your phone's screen with your clicking hand.",
                            
                            "For the best experience, keep your on-screen hand so that your device's back-facing camera can see it. Keep your hand oriented so that all of your fingers are visible.",
                            
                            "Virtual objects are selected using the center of your palm on your on-screen hand."
                        ]
                        
                        let end = description.tutorialExtension?.split(separator: "\n").map{ String($0) } ?? []
                        
                        Text((start + end).reduce(into: "") {
                            $0 += "\n\($1)\n"
                        })
                            .padding([.leading, .trailing], 20)
                        
                        Text("""
                        Some of the latest iPhones and iPads have a built-in LiDAR scanner, which allows a device to understand the 3D shape of its surroundings. On these devices, this app uses the scanner to more realistically render your surroundings and reconstruct the 3D position of your on-screen hand. If your device has a LiDAR scanner, you will see "Scene Reconstruction" and "Hand Reconstruction" as options in the settings panel.
                        
                        """)
                        
                        if !coordinator.canCloseTutorial {
                            VStack(alignment: .leading) {
                                VStack {
                                    Toggle(isOn: $coordinator.appTutorialCheck.check1) {
                                        Text("I read the above tutorial")
                                    }
                                    
                                    Toggle(isOn: $coordinator.appTutorialCheck.check2) {
                                        Text("I know how to access the settings panel")
                                    }
                                    .disabled(!coordinator.appTutorialCheck.check1)
                                    
                                    Toggle(isOn: $coordinator.appTutorialCheck.check3) {
                                        Text("I know how to \(description.mainActivity) with my on-screen hand")
                                    }
                                    .disabled(!coordinator.appTutorialCheck.check1)
                                }
                                .frame(maxWidth: UIScreen.main.bounds.width, alignment: .center)
                                
                                Text("You can access this tutorial at any time through the settings panel.")
                                    .frame(alignment: .leading)
                            }
                            .padding(.bottom, 20)
                        }
                        
                        VStack {
                            Button("Close Tutorial") {
                                coordinator.showingAppTutorial = false
                                
                                if !coordinator.canCloseTutorial {
                                    coordinator.canCloseTutorial = true
                                }
                            }
                            .disabled({
                                if coordinator.canCloseTutorial {
                                    return false
                                }
                                
                                let check = coordinator.appTutorialCheck
                                
                                return !check.check1 || !check.check2 || !check.check3
                            }())
                        }
                        .frame(maxWidth: UIScreen.main.bounds.width, alignment: .center)
                    }
                    .frame(alignment: .leading)
                }
                .padding([.leading, .trailing, .bottom], 20)
                .fixedSize(horizontal: false, vertical: true)
            }
            .fixFlickering { $0
                .frame(maxWidth: UIScreen.main.bounds.width, alignment: .center)
            }
        }
    }
}
#endif

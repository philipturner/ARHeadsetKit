//
//  HeadsetTutorialView.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/23/21.
//

#if !os(macOS)
import SwiftUI

struct HeadsetTutorialView<Coordinator: AppCoordinator>: View {
    @ObservedObject var coordinator: Coordinator
    
    typealias CaseSize = LensDistortionCorrector.StoredSettings.CaseSize
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack {
                VStack {
                    Text("Using Google Cardboard with \(coordinator.appDescription.name)")
                        .font(.headline)
                }
                
                VStack(alignment: .leading) {
                    Text("""
                    
                    Google Cardboard is a VR headset that uses your iPhone's screen to display virtual content. This app uses Google Cardboard for an AR experience. As a result, Google Cardboard must be used differently than with most VR experiences.
                    
                    To use headset mode, leave Google Cardboard's back flap open and place your device over the rubber band. Ensure the white view separator aligns with the middle of your headset, and hold the device in place with your right hand. Position your hand so that you can hold your device in place while also holding the headset and tapping Google Cardboard's side button with your right hand. When interacting with virtual objects, tap Google Cardboard's side button instead of your device's screen.
                    
                    When using the Google Cardboard headset, use it in an open area and be mindful of your surroundings and nearby people. Although representing your surroundings in VR allows you to have an immersive experience, it narrows your peripheral vision and is subject to the same safety precautions as with all other VR experiences.
                    
                    You might accidentally drop your device since it is not anchored in place by Google Cardboard's back flap. Please keep your device in a protective case. Leaving a case on will affect how your phone's screen aligns with your eyes. To help VR content align more closely with your eyes, select your case's approximate thickness as described below:
                    
                    """)
                    
                    Picker("Case Size", selection: $coordinator.caseSize) {
                        Text("Small").tag(CaseSize.small)
                        Text("Large").tag(CaseSize.large)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text("""
                    Case size: choose "small" for a thin silicone or clear case, or "large" for a bulky case
                    """)
                        .font(.caption)
                }
            }
            .padding([.leading, .trailing, .bottom], 20)
            .fixedSize(horizontal: false, vertical: true)
        }
        .fixFlickering { $0
            .padding(.top, 20)
        }
    }
}
#endif

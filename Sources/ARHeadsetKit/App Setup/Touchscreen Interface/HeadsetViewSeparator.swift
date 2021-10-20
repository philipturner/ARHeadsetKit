//
//  HeadsetViewSeparator.swift
//  ARHeadsetKit
//
//  Created by Philip Turner on 8/23/21.
//

#if !os(macOS)
import SwiftUI

struct HeadsetViewSeparator<Coordinator: AppCoordinator>: View {
    @ObservedObject var coordinator: Coordinator
    
    var body: some View {
        if coordinator.renderingSettings.usingHeadsetMode,
           coordinator.renderingSettings.renderingViewSeparator {
            SeparatorView(coordinator: coordinator)
        }
    }
    
    private struct SeparatorView: UIViewRepresentable {
        @ObservedObject var coordinator: Coordinator

        func makeCoordinator() -> Coordinator { coordinator }

        func makeUIView(context: Context) -> UIView { coordinator.separatorView }
        func updateUIView(_ uiView: UIView, context: Context) { }
    }
    
    static var separatorView: UIView {
        let separatorRadius: CGFloat = 1.5
        let separatorToSideDistance: CGFloat = 10
        let bounds = UIScreen.main.bounds
        
        let path = UIBezierPath()
        path.addArc(withCenter: CGPoint(x: separatorToSideDistance + separatorRadius,
                                        y: bounds.height * 0.5),
                    radius: separatorRadius,
                    startAngle: degreesToRadians(90),
                    endAngle:   degreesToRadians(270),
                    clockwise: true)
        
        path.addLine(to: CGPoint(x: bounds.width        - separatorRadius - separatorToSideDistance,
                                 y: bounds.height * 0.5 - separatorRadius))

        path.addArc(withCenter: CGPoint(x: bounds.width - separatorRadius - separatorToSideDistance,
                                        y: bounds.height * 0.5),
                    radius: separatorRadius,
                    startAngle: degreesToRadians(270),
                    endAngle:   degreesToRadians(450),
                    clockwise: true)

        path.addLine(to: CGPoint(x: separatorRadius     + separatorRadius,
                                 y: bounds.height * 0.5 + separatorRadius))
        
        path.close()
        
        
        
        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.white.cgColor
        shapeLayer.lineWidth = 0
        
        let view = UIView()
        view.layer.addSublayer(shapeLayer)
        return view
    }
}
#endif

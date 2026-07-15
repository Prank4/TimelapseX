//
//  CameraLevelView.swift
//  TimelapseX
//
//  Created by Prank on 14/07/26.
//

import SwiftUI

struct CameraLevelView: View {
    let angleDegrees: Double?

    private var isLevel: Bool {
        guard let angleDegrees else { return false }
        return abs(angleDegrees) <= 1
    }

    var body: some View {
        if let angleDegrees {
            HStack(spacing: 8) {
                levelLine
                Capsule()
                    .fill(isLevel ? Color.yellow : Color.white)
                    .frame(width: 42, height: isLevel ? 3 : 2)
                levelLine
            }
            .frame(width: 190, height: 50)
            .rotationEffect(.degrees(-angleDegrees))
            .animation(.linear(duration: 0.08), value: angleDegrees)
            .shadow(color: .black.opacity(0.7), radius: 2, y: 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Camera level")
            .accessibilityValue(isLevel ? "Level" : "\(Int(abs(angleDegrees).rounded())) degrees off level")
        }
    }

    private var levelLine: some View {
        Capsule()
            .fill(isLevel ? Color.yellow : Color.white.opacity(0.9))
            .frame(width: 58, height: 2)
    }
}

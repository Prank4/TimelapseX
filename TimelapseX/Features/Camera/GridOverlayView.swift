//
//  GridOverlayView.swift
//  TimelapseX
//
//  Created by Prank on 02/07/26.
//

import SwiftUI

struct GridOverlayView: View {
    let type: GridOverlay

    var body: some View {
        GeometryReader { geometry in
            switch type {
            case .off:
                EmptyView()
            case .ruleOfThirds:
                thirdsGrid(in: geometry.size)
            case .centerCross:
                centerCrossGrid(in: geometry.size)
            }
        }
    }

    private func thirdsGrid(in size: CGSize) -> some View {
        Path { path in
            // Horizontal lines
            let hSpacing = size.height / 3
            path.move(to: CGPoint(x: 0, y: hSpacing))
            path.addLine(to: CGPoint(x: size.width, y: hSpacing))

            path.move(to: CGPoint(x: 0, y: hSpacing * 2))
            path.addLine(to: CGPoint(x: size.width, y: hSpacing * 2))

            // Vertical lines
            let wSpacing = size.width / 3
            path.move(to: CGPoint(x: wSpacing, y: 0))
            path.addLine(to: CGPoint(x: wSpacing, y: size.height))

            path.move(to: CGPoint(x: wSpacing * 2, y: 0))
            path.addLine(to: CGPoint(x: wSpacing * 2, y: size.height))
        }
        .stroke(Color.white.opacity(0.35), lineWidth: 1)
    }

    private func centerCrossGrid(in size: CGSize) -> some View {
        Path { path in
            // Horizontal line
            path.move(to: CGPoint(x: 0, y: size.height / 2))
            path.addLine(to: CGPoint(x: size.width, y: size.height / 2))

            // Vertical line
            path.move(to: CGPoint(x: size.width / 2, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
        }
        .stroke(Color.white.opacity(0.35), lineWidth: 1)
    }
}

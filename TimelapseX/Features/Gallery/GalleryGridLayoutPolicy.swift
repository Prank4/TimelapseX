//
//  GalleryGridLayoutPolicy.swift
//  TimelapseX
//
//  Created by Prank on 14/07/26.
//

import Foundation

enum GalleryGridLayoutPolicy {
    static let minimumColumnCount = 2
    static let maximumColumnCount = 8

    static func clampedColumnCount(_ value: Int) -> Int {
        min(max(value, minimumColumnCount), maximumColumnCount)
    }

    static func columnCount(startingAt value: Int, magnification: CGFloat) -> Int {
        guard magnification > 0 else { return clampedColumnCount(value) }
        let scaled = Int((CGFloat(value) / magnification).rounded())
        return clampedColumnCount(scaled)
    }
}

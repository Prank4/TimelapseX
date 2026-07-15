//
//  SessionRotationPolicy.swift
//  TimelapseX
//
//  Created by Prank on 14/07/26.
//

import Foundation

enum SessionRotationPolicy {
    static let inactivityInterval: TimeInterval = 5 * 60

    static func shouldRotate(
        frameCount: Int,
        lastCaptureAt: Date?,
        now: Date,
        inactivityInterval: TimeInterval = inactivityInterval
    ) -> Bool {
        guard frameCount > 0, let lastCaptureAt else { return false }
        return now.timeIntervalSince(lastCaptureAt) >= inactivityInterval
    }

    static func deadline(
        frameCount: Int,
        lastCaptureAt: Date?,
        inactivityInterval: TimeInterval = inactivityInterval
    ) -> Date? {
        guard frameCount > 0, let lastCaptureAt else { return nil }
        return lastCaptureAt.addingTimeInterval(inactivityInterval)
    }
}

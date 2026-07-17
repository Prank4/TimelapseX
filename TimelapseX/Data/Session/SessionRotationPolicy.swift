//
//  SessionRotationPolicy.swift
//  TimelapseX
//
//  Created by Prank on 14/07/26.
//

import Foundation

enum SessionRotationPolicy {
    nonisolated static let defaultInactivityMinutes = 5.0
    nonisolated static let minimumInactivityMinutes = 5.0
    nonisolated static let maximumInactivityMinutes = 60.0
    nonisolated static let inactivityMinuteStep = 5.0
    nonisolated static let inactivityInterval: TimeInterval = defaultInactivityMinutes * 60

    nonisolated static func clampedInactivityMinutes(_ minutes: Double) -> Double {
        let clamped = min(max(minutes, minimumInactivityMinutes), maximumInactivityMinutes)
        return (clamped / inactivityMinuteStep).rounded() * inactivityMinuteStep
    }

    nonisolated static func inactivityIntervalSeconds(minutes: Double) -> TimeInterval {
        clampedInactivityMinutes(minutes) * 60
    }

    nonisolated static func shouldRotate(
        frameCount: Int,
        lastCaptureAt: Date?,
        now: Date,
        isEnabled: Bool = true,
        inactivityInterval: TimeInterval = inactivityInterval
    ) -> Bool {
        guard isEnabled, frameCount > 0, let lastCaptureAt else { return false }
        return now.timeIntervalSince(lastCaptureAt) >= inactivityInterval
    }

    nonisolated static func deadline(
        frameCount: Int,
        lastCaptureAt: Date?,
        isEnabled: Bool = true,
        inactivityInterval: TimeInterval = inactivityInterval
    ) -> Date? {
        guard isEnabled, frameCount > 0, let lastCaptureAt else { return nil }
        return lastCaptureAt.addingTimeInterval(inactivityInterval)
    }
}

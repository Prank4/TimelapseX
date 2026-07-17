//
//  FrameDurationPolicy.swift
//  TimelapseX
//
//  Created by Prank on 15/07/26.
//

import Foundation

enum FrameDurationPolicy {
    nonisolated static let defaultGlobalDuration = 1.0 / 24.0
    nonisolated static let minimumGlobalDuration = 0.01
    nonisolated static let maximumGlobalDuration = 0.1
    nonisolated static let minimumOverrideDuration = 0.5
    nonisolated static let maximumOverrideDuration = 5.0
    nonisolated static let overrideStep = 0.5

    nonisolated static func clampedGlobal(_ duration: TimeInterval) -> TimeInterval {
        min(max(duration, minimumGlobalDuration), maximumGlobalDuration)
    }

    nonisolated static func clampedOverride(_ duration: TimeInterval) -> TimeInterval {
        let clamped = min(max(duration, minimumOverrideDuration), maximumOverrideDuration)
        return (clamped / overrideStep).rounded() * overrideStep
    }

    nonisolated static func effectiveDuration(
        for frameFilename: String,
        globalDuration: TimeInterval,
        overrides: [String: TimeInterval]
    ) -> TimeInterval {
        guard let override = overrides[frameFilename] else {
            return clampedGlobal(globalDuration)
        }
        return clampedOverride(override)
    }

    nonisolated static func totalDuration(
        frameFilenames: [String],
        globalDuration: TimeInterval,
        overrides: [String: TimeInterval]
    ) -> TimeInterval {
        frameFilenames.reduce(0) { total, filename in
            total + effectiveDuration(
                for: filename,
                globalDuration: globalDuration,
                overrides: overrides
            )
        }
    }

    nonisolated static func presentationTimes(
        frameFilenames: [String],
        globalDuration: TimeInterval,
        overrides: [String: TimeInterval]
    ) -> [TimeInterval] {
        var elapsed: TimeInterval = 0
        return frameFilenames.map { filename in
            defer {
                elapsed += effectiveDuration(
                    for: filename,
                    globalDuration: globalDuration,
                    overrides: overrides
                )
            }
            return elapsed
        }
    }
}

//
//  CameraControlPolicy.swift
//  TimelapseX
//
//  Created by Prank on 19/07/26.
//

enum LatestPhotoPreviewPolicy {
    nonisolated static let defaultDuration = 30.0
    nonisolated static let minimumDuration = 30.0
    nonisolated static let maximumDuration = 300.0
    nonisolated static let durationStep = 30.0

    nonisolated static func clampedDuration(_ seconds: Double) -> Double {
        let clamped = min(max(seconds, minimumDuration), maximumDuration)
        return (clamped / durationStep).rounded() * durationStep
    }
}

enum CameraZoomPolicy {
    nonisolated static let maximumUserZoom = 10.0

    nonisolated static func clampedZoom(
        _ requestedZoom: Double,
        deviceMinimum: Double,
        deviceMaximum: Double
    ) -> Double {
        let minimum = max(1, deviceMinimum)
        let maximum = max(minimum, min(deviceMaximum, maximumUserZoom))
        return min(max(requestedZoom, minimum), maximum)
    }

    nonisolated static func zoom(
        startingZoom: Double,
        magnification: Double,
        deviceMinimum: Double,
        deviceMaximum: Double
    ) -> Double {
        clampedZoom(
            startingZoom * magnification,
            deviceMinimum: deviceMinimum,
            deviceMaximum: deviceMaximum
        )
    }
}

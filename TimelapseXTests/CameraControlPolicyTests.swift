import Testing
@testable import TimelapseXCameraLogic

struct CameraControlPolicyTests {
    @Test func previewDurationUsesThirtySecondSteps() {
        #expect(LatestPhotoPreviewPolicy.clampedDuration(1) == 30)
        #expect(LatestPhotoPreviewPolicy.clampedDuration(44) == 30)
        #expect(LatestPhotoPreviewPolicy.clampedDuration(46) == 60)
        #expect(LatestPhotoPreviewPolicy.clampedDuration(600) == 300)
    }

    @Test func zoomClampsToDeviceAndAppLimits() {
        #expect(CameraZoomPolicy.clampedZoom(0.5, deviceMinimum: 1, deviceMaximum: 15) == 1)
        #expect(CameraZoomPolicy.clampedZoom(20, deviceMinimum: 1, deviceMaximum: 15) == 10)
        #expect(CameraZoomPolicy.clampedZoom(8, deviceMinimum: 1, deviceMaximum: 5) == 5)
    }

    @Test func magnificationBuildsFromGestureStartingZoom() {
        #expect(CameraZoomPolicy.zoom(
            startingZoom: 2,
            magnification: 1.5,
            deviceMinimum: 1,
            deviceMaximum: 10
        ) == 3)
    }
}

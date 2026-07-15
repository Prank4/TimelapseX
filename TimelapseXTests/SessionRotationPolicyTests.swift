import Foundation
import Testing
@testable import TimelapseXSessionLogic

struct SessionRotationPolicyTests {
    private let lastCapture = Date(timeIntervalSince1970: 1_000)

    @Test func emptySessionNeverRotates() {
        #expect(!SessionRotationPolicy.shouldRotate(
            frameCount: 0,
            lastCaptureAt: lastCapture,
            now: lastCapture.addingTimeInterval(600)
        ))
    }

    @Test func sessionWithPhotosDoesNotRotateBeforeFiveMinutes() {
        #expect(!SessionRotationPolicy.shouldRotate(
            frameCount: 1,
            lastCaptureAt: lastCapture,
            now: lastCapture.addingTimeInterval(299)
        ))
    }

    @Test func sessionWithPhotosRotatesAtFiveMinutes() {
        #expect(SessionRotationPolicy.shouldRotate(
            frameCount: 1,
            lastCaptureAt: lastCapture,
            now: lastCapture.addingTimeInterval(300)
        ))
    }

    @Test func missingCaptureDateDoesNotRotate() {
        #expect(!SessionRotationPolicy.shouldRotate(
            frameCount: 3,
            lastCaptureAt: nil,
            now: lastCapture.addingTimeInterval(600)
        ))
    }
}

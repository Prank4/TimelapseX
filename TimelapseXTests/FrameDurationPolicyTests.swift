import Foundation
import Testing
@testable import TimelapseXSessionLogic

struct FrameDurationPolicyTests {
    private let frames = ["IMG_000001.jpg", "IMG_000002.jpg", "IMG_000003.jpg"]

    @Test func frameWithoutOverrideUsesGlobalDuration() {
        #expect(FrameDurationPolicy.effectiveDuration(
            for: frames[0],
            globalDuration: 0.04,
            overrides: [:]
        ) == 0.04)
    }

    @Test func frameOverrideReplacesGlobalDuration() {
        #expect(FrameDurationPolicy.effectiveDuration(
            for: frames[0],
            globalDuration: 0.04,
            overrides: [frames[0]: 2.5]
        ) == 2.5)
    }

    @Test func removingOverrideRestoresGlobalDuration() {
        var overrides = [frames[0]: 2.5]
        overrides[frames[0]] = nil

        #expect(FrameDurationPolicy.effectiveDuration(
            for: frames[0],
            globalDuration: 0.04,
            overrides: overrides
        ) == 0.04)
    }

    @Test func estimatedDurationIncludesOverrides() {
        let total = FrameDurationPolicy.totalDuration(
            frameFilenames: frames,
            globalDuration: 0.04,
            overrides: [frames[1]: 2.0]
        )

        #expect(abs(total - 2.08) < 0.000_001)
    }

    @Test func presentationTimesAreCumulative() {
        let times = FrameDurationPolicy.presentationTimes(
            frameFilenames: frames,
            globalDuration: 0.04,
            overrides: [frames[1]: 2.0]
        )

        #expect(times.count == 3)
        #expect(abs(times[0] - 0) < 0.000_001)
        #expect(abs(times[1] - 0.04) < 0.000_001)
        #expect(abs(times[2] - 2.04) < 0.000_001)
    }

    @Test func overrideRangeUsesHalfSecondStepsThroughFiveSeconds() {
        #expect(FrameDurationPolicy.clampedOverride(0.1) == 0.5)
        #expect(FrameDurationPolicy.clampedOverride(6) == 5)
        #expect(FrameDurationPolicy.clampedOverride(2.26) == 2.5)
    }
}

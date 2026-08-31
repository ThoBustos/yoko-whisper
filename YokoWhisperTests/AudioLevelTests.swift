import XCTest
@testable import YokoWhisper

final class AudioLevelTests: XCTestCase {
    func testSmootherClampsAndRisesWithoutOvershooting() {
        var smoother = AudioLevelSmoother()

        smoother.update(rawLevel: 2)

        XCTAssertGreaterThan(smoother.value, 0)
        XCTAssertLessThanOrEqual(smoother.value, 1)
    }

    func testSmootherUsesAQuickerAttackThanRelease() {
        var attack = AudioLevelSmoother()
        attack.update(rawLevel: 1)
        let rise = attack.value

        var release = AudioLevelSmoother()
        release.update(rawLevel: 1)
        let peak = release.value
        release.update(rawLevel: 0)

        XCTAssertGreaterThan(rise, peak - release.value)
    }

    func testWaveformAlwaysReturnsFiveBoundedBars() {
        let samples = WaveformLevels.samples(level: 4)

        XCTAssertEqual(samples.count, 5)
        XCTAssertTrue(samples.allSatisfy { (0...1).contains($0) })
    }

    func testSmootherResetsBetweenRecordingSessions() {
        var smoother = AudioLevelSmoother()
        smoother.update(rawLevel: 1)

        smoother.reset()

        XCTAssertEqual(smoother.value, 0)
    }
}

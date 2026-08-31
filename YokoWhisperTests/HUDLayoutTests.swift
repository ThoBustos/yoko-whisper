import XCTest
@testable import YokoWhisper

final class HUDLayoutTests: XCTestCase {
    func testHUDIsCenteredBelowTheVisibleScreenTop() {
        let frame = CGRect(x: 100, y: 50, width: 1_000, height: 700)

        let origin = HUDLayout.origin(panelSize: HUDLayout.recordingSize, visibleFrame: frame)

        XCTAssertEqual(origin.x, frame.midX - HUDLayout.recordingSize.width / 2)
        XCTAssertEqual(origin.y, frame.maxY - HUDLayout.recordingSize.height - HUDLayout.topInset)
    }

    func testRecordingHUDIsSmallerThanStatusHUD() {
        XCTAssertLessThan(HUDLayout.size(for: .recording(startedAt: .now)).width, HUDLayout.size(for: .transcribing).width)
    }

    func testHUDUsesTheSelectedDisplaysCoordinateSpace() {
        let secondaryDisplay = CGRect(x: -1_920, y: 180, width: 1_920, height: 1_080)

        let origin = HUDLayout.origin(panelSize: HUDLayout.statusSize, visibleFrame: secondaryDisplay)

        XCTAssertEqual(origin.x, secondaryDisplay.midX - HUDLayout.statusSize.width / 2)
        XCTAssertEqual(origin.y, secondaryDisplay.maxY - HUDLayout.statusSize.height - HUDLayout.topInset)
    }
}

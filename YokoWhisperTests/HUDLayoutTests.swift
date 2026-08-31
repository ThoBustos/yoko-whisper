import XCTest
@testable import YokoWhisper

final class HUDLayoutTests: XCTestCase {
    func testHUDIsCenteredBelowTheVisibleScreenTop() {
        let frame = CGRect(x: 100, y: 50, width: 1_000, height: 700)

        let origin = HUDLayout.origin(visibleFrame: frame)

        XCTAssertEqual(origin.x, frame.midX - HUDLayout.size.width / 2)
        XCTAssertEqual(origin.y, frame.maxY - HUDLayout.size.height - HUDLayout.topInset)
    }
}

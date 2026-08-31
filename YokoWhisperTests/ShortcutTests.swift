import XCTest
@testable import YokoWhisper

final class ShortcutTests: XCTestCase {
    func testTranscribingStateRejectsToggle() {
        XCTAssertEqual(DictationReducer.reduce(.transcribing, .toggle).label, "TRANSCRIBING")
    }
}

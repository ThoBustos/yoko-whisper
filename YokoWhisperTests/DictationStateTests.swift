import XCTest
@testable import YokoWhisper

final class DictationStateTests: XCTestCase {
    func testOverlappingToggleIsIgnoredWhileTranscribing() {
        XCTAssertEqual(DictationReducer.reduce(.transcribing, .toggle), .transcribing)
    }
    func testRecordingCanCancel() {
        XCTAssertEqual(DictationReducer.reduce(.recording(startedAt: .now), .cancel), .cancelled)
    }
}

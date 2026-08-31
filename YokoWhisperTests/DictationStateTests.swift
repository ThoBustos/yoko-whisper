import XCTest
@testable import YokoWhisper

final class DictationStateTests: XCTestCase {
    func testOverlappingPressIsIgnoredWhileTranscribing() {
        XCTAssertEqual(DictationReducer.reduce(.transcribing, .press), .transcribing)
    }
    func testRecordingCanCancel() {
        XCTAssertEqual(DictationReducer.reduce(.recording(startedAt: .now), .cancel), .cancelled)
    }

    func testReleaseFinishesRecording() {
        XCTAssertEqual(DictationReducer.reduce(.recording(startedAt: .now), .release), .transcribing)
    }

    func testOnlyTerminalStatesCanBeginRecording() {
        XCTAssertTrue(DictationState.idle.canBeginRecording)
        XCTAssertTrue(DictationState.cancelled.canBeginRecording)
        XCTAssertFalse(DictationState.transcribing.canBeginRecording)
        XCTAssertFalse(DictationState.inserting.canBeginRecording)
    }

    func testInvalidAndOverlappingTransitionsDoNotAdvanceTheSession() {
        let cases: [(DictationState, DictationEvent)] = [
            (.idle, .release),
            (.idle, .cancel),
            (.recording(startedAt: .distantPast), .press),
            (.transcribing, .press),
            (.transcribing, .release),
            (.inserting, .press),
        ]

        for (state, event) in cases {
            XCTAssertEqual(DictationReducer.reduce(state, event), state)
        }
    }
}

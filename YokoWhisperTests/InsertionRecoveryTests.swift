import XCTest
@testable import YokoWhisper

final class InsertionRecoveryTests: XCTestCase {
    func testFailureCanRetainTranscript() {
        let state = DictationState.failure("Target closed", transcript: "Recovered words")
        guard case .failure(_, let transcript) = state else { return XCTFail() }
        XCTAssertEqual(transcript, "Recovered words")
    }

    func testMissingTargetExplainsClipboardRecovery() {
        XCTAssertTrue(InsertionError.noTarget.localizedDescription.contains("copied"))
    }
}

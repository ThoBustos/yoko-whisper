import XCTest
@testable import YokoWhisper

final class InsertionRecoveryTests: XCTestCase {
    @MainActor
    func testSavedTranscriptCanBeCleared() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("Sensitive words", forKey: "lastTranscript")

        let coordinator = DictationCoordinator(defaults: defaults)
        XCTAssertEqual(coordinator.lastTranscript, "Sensitive words")

        coordinator.clearLastTranscript()

        XCTAssertNil(coordinator.lastTranscript)
        XCTAssertNil(defaults.string(forKey: "lastTranscript"))
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFailureCanRetainTranscript() {
        let state = DictationState.failure("Target closed", transcript: "Recovered words")
        guard case .failure(_, let transcript) = state else { return XCTFail() }
        XCTAssertEqual(transcript, "Recovered words")
    }

    func testMissingTargetExplainsClipboardRecovery() {
        XCTAssertEqual(
            InsertionPolicy.strategy(
                hasTarget: false,
                isSecure: false,
                supportsDirectInsertion: false,
                hasEditableRole: false
            ),
            .copy
        )
    }

    func testSecureFieldsOnlyCopyTheTranscript() {
        XCTAssertEqual(
            InsertionPolicy.strategy(
                hasTarget: true,
                isSecure: true,
                supportsDirectInsertion: true,
                hasEditableRole: true
            ),
            .copy
        )
    }

    func testDirectInsertionWinsWhenSupported() {
        XCTAssertEqual(
            InsertionPolicy.strategy(
                hasTarget: true,
                isSecure: false,
                supportsDirectInsertion: true,
                hasEditableRole: true
            ),
            .direct
        )
    }

    func testEditableTargetsFallBackToPaste() {
        XCTAssertEqual(
            InsertionPolicy.strategy(
                hasTarget: true,
                isSecure: false,
                supportsDirectInsertion: false,
                hasEditableRole: true
            ),
            .paste
        )
    }

    func testSyntheticPasteRequiresTheSameFrontmostNonSecureEditableTarget() {
        XCTAssertTrue(InsertionPolicy.allowsSyntheticPaste(
            applicationIsFrontmost: true,
            focusMatches: true,
            isSecure: false,
            hasEditableRole: true
        ))

        let unsafeCases = [
            (false, true, false, true),
            (true, false, false, true),
            (true, true, true, true),
            (true, true, false, false),
        ]
        for (frontmost, matching, secure, editable) in unsafeCases {
            XCTAssertFalse(InsertionPolicy.allowsSyntheticPaste(
                applicationIsFrontmost: frontmost,
                focusMatches: matching,
                isSecure: secure,
                hasEditableRole: editable
            ))
        }
    }

    func testPasteRequestIsNotReportedAsConfirmedInsertion() {
        XCTAssertNotEqual(InsertionResult.pasteRequested, .insertedDirectly)
    }
}

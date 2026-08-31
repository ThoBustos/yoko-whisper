import XCTest
@testable import YokoWhisper

@MainActor
final class TranscriptionEngineTests: XCTestCase {
    func testInitialReadinessDoesNotClaimDownloadedModel() {
        XCTAssertEqual(WhisperKitEngine().readiness, .notDownloaded)
    }
}

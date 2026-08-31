import XCTest
@testable import YokoWhisper

final class BrandTests: XCTestCase {
    func testAppModelStartsReady() async {
        await MainActor.run { XCTAssertEqual(AppModel().status, "READY") }
    }
}

import XCTest
@testable import YokoWhisper

final class PermissionStateTests: XCTestCase {
    func testPermissionLabelsAreStable() {
        XCTAssertEqual(PermissionState.granted.rawValue, "granted")
        XCTAssertEqual(PermissionState.denied.rawValue, "denied")
    }

    @MainActor
    func testRefreshProducesCurrentStatuses() {
        let service = PermissionService()
        service.refresh()
        XCTAssertNotEqual(service.microphone.rawValue, "")
        XCTAssertNotEqual(service.accessibility.rawValue, "")
    }
}

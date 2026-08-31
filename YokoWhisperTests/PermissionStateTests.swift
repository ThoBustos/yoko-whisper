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

    func testIntegrationInitializationIsIdempotent() {
        var lifecycle = IntegrationLifecycle()

        XCTAssertTrue(lifecycle.beginIfNeeded())
        XCTAssertFalse(lifecycle.beginIfNeeded())
    }

    func testShortcutFailureGuidanceIdentifiesTheMissingPermission() {
        XCTAssertTrue(ShortcutPermissionGuidance.message(
            accessibilityGranted: false,
            listenGranted: false
        ).contains("Accessibility"))
        XCTAssertTrue(ShortcutPermissionGuidance.message(
            accessibilityGranted: true,
            listenGranted: false
        ).contains("Input Monitoring"))
        XCTAssertTrue(ShortcutPermissionGuidance.message(
            accessibilityGranted: true,
            listenGranted: true
        ).contains("conflict"))
    }
}

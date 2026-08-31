import XCTest
@testable import YokoWhisper

@MainActor
final class PreferencesTests: XCTestCase {
    func testDefaultsFallBackToFnSpaceAndAutoLanguage() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let preferences = Preferences(defaults: suite)
        XCTAssertEqual(preferences.shortcut, .fnSpace)
        XCTAssertEqual(preferences.language, "auto")
    }
}

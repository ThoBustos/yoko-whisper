import XCTest
@testable import YokoWhisper

final class AppSoundPlayerTests: XCTestCase {
    func testBundledRecordingSoundsAreAvailable() {
        for sound in AppSound.allCases {
            XCTAssertNotNil(
                Bundle.main.url(forResource: sound.rawValue, withExtension: "mp3"),
                "Missing bundled sound: \(sound.rawValue).mp3"
            )
        }
    }
}

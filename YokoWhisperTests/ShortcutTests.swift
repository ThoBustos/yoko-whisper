import XCTest
@testable import YokoWhisper

final class ShortcutTests: XCTestCase {
    func testPressAndReleaseProduceOneTransitionEach() {
        var state = ShortcutPressState()

        XCTAssertEqual(state.transition(.down), .pressed)
        XCTAssertNil(state.transition(.down))
        XCTAssertEqual(state.transition(.up), .released)
        XCTAssertNil(state.transition(.up))
    }

    func testAutoRepeatDoesNotStartARecording() {
        var state = ShortcutPressState()

        XCTAssertNil(state.transition(.down, isRepeat: true))
        XCTAssertFalse(state.isPressed)
    }

    func testAutoRepeatDoesNotProduceAnotherPress() {
        var state = ShortcutPressState()

        XCTAssertEqual(state.transition(.down), .pressed)
        XCTAssertNil(state.transition(.down, isRepeat: true))
        XCTAssertEqual(state.transition(.up), .released)
    }

    func testRapidTransitionsRemainPairedAndDuplicatesAreIgnored() {
        var state = ShortcutPressState()

        let transitions = [
            state.transition(.down),
            state.transition(.down),
            state.transition(.up),
            state.transition(.up),
        ].compactMap { $0 }

        XCTAssertEqual(transitions, [.pressed, .released])
        XCTAssertFalse(state.isPressed)
    }
}

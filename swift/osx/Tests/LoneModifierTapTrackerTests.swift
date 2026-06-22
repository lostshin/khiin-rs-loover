import XCTest
@testable import KhiinPJH

final class LoneModifierTapTrackerTests: XCTestCase {
    private let leftShift: UInt16 = 1
    private let rightShift: UInt16 = 2

    func testSinglePhysicalModifierTogglesOnRelease() {
        var tracker = LoneModifierTapTracker(
            targetKeyCodes: [leftShift, rightShift])

        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: leftShift))
        XCTAssertTrue(tracker.handleTargetKeyChange(keyCode: leftShift))
    }

    func testTwoShiftKeysCancelTheSequence() {
        var tracker = LoneModifierTapTracker(
            targetKeyCodes: [leftShift, rightShift])

        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: leftShift))
        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: rightShift))
        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: leftShift))
        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: rightShift))
    }

    func testAnotherModifierCancelsTheSequence() {
        var tracker = LoneModifierTapTracker(
            targetKeyCodes: [leftShift, rightShift])

        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: leftShift))
        tracker.cancel()
        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: leftShift))
    }

    func testNormalKeyCancelsTheSequence() {
        var tracker = LoneModifierTapTracker(
            targetKeyCodes: [leftShift, rightShift])

        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: rightShift))
        tracker.cancel()
        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: rightShift))
    }

    func testSideSpecificShortcutIgnoresTheOtherSide() {
        var tracker = LoneModifierTapTracker(targetKeyCodes: [rightShift])

        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: rightShift))
        tracker.cancel()
        XCTAssertFalse(tracker.handleTargetKeyChange(keyCode: rightShift))
    }
}

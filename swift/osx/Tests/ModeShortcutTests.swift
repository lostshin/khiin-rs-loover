import AppKit
import XCTest
@testable import KhiinPJH

final class ModeShortcutTests: XCTestCase {
    func testUnknownCodeIsRejected() {
        XCTAssertNil(ModeShortcut.parse("Control+F12"))
    }

    func testMalformedModifierIsRejected() {
        XCTAssertNil(ModeShortcut.parse("Hyper+KeyM"))
    }

    func testCombinationRequiresAModifier() {
        XCTAssertNil(ModeShortcut.parse("KeyM"))
    }

    func testKhiinReservedOptionShortcutIsRejected() {
        XCTAssertNil(ModeShortcut.parse("Alt+KeyH"))
        XCTAssertNil(ModeShortcut.parse("Alt+Shift+KeyH"))
        XCTAssertNil(ModeShortcut.parse("Alt+KeyS"))
        XCTAssertNil(ModeShortcut.parse("Alt+KeyL"))
        XCTAssertNil(ModeShortcut.parse("Alt+Space"))
    }

    func testMacOSReservedShortcutIsRejected() {
        XCTAssertNil(ModeShortcut.parse("Meta+KeyC"))
        XCTAssertNil(ModeShortcut.parse("Meta+KeyB"))
        XCTAssertNil(ModeShortcut.parse("Meta+Space"))
        XCTAssertNil(ModeShortcut.parse("Control+Space"))
        XCTAssertNil(ModeShortcut.parse("Control+Alt+Space"))
        XCTAssertNil(ModeShortcut.parse("Control+Alt+KeyM"))
        XCTAssertNil(ModeShortcut.parse("Control+KeyA"))
        XCTAssertNil(ModeShortcut.parse("Shift+Meta+Digit4"))
    }

    func testSupportedShortcutMatchesExactModifiers() throws {
        let shortcut = try XCTUnwrap(ModeShortcut.parse("Control+KeyM"))

        XCTAssertTrue(
            shortcut.matchesKeyDown(
                keyCode: KeyCode.Alphabet.VK_M,
                modifiers: [.control]))
        XCTAssertFalse(
            shortcut.matchesKeyDown(
                keyCode: KeyCode.Alphabet.VK_M,
                modifiers: [.control, .shift]))
    }

    func testDefaultShortcutStillMatchesOptionBackquote() throws {
        let shortcut = try XCTUnwrap(ModeShortcut.parse("default"))

        XCTAssertTrue(
            shortcut.matchesKeyDown(
                keyCode: KeyCode.Symbol.VK_BACKQUOTE,
                modifiers: [.option]))
    }
}

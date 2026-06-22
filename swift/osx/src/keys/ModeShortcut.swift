import InputMethodKit

/// A user-configurable shortcut for toggling the input mode (動/由), parsed from
/// the `input_mode_shortcut` setting written by the settings app. The setting app
/// records keys as W3C UI Events `code` names (physical-position based, so they
/// map cleanly to macOS virtual key codes regardless of keyboard layout).
///
/// Accepted forms:
///   - "default"               → platform default (macOS: ⌥ + `)
///   - "shift"                 → a lone Shift tap (legacy / Windows value)
///   - "<Modifier>Left|Right"  → a lone modifier-key tap, e.g. "MetaRight"
///   - "<Mod>+…+<Code>"        → a key combo; each <Mod> is Shift/Control/Alt/Meta
///                               and <Code> is a W3C `code`, e.g. "Alt+Backquote",
///                               "Control+KeyM"
enum ModeShortcut {
    /// A normal key pressed together with an exact set of modifiers.
    case combo(keyCode: UInt16, modifiers: NSEvent.ModifierFlags)
    /// A modifier key tapped on its own (press + release, nothing in between).
    case loneModifier(keyCodes: Set<UInt16>, flag: NSEvent.ModifierFlags)

    private static let backquoteDefault: ModeShortcut =
        .combo(keyCode: KeyCode.Symbol.VK_BACKQUOTE, modifiers: [.option])

    static func parse(_ raw: String) -> ModeShortcut? {
        switch raw {
        case "", "default":
            return backquoteDefault
        case "shift", "Shift":
            // Side-agnostic Shift (the legacy / Windows-compatible value).
            return .loneModifier(
                keyCodes: [
                    KeyCode.Modifier.VK_SHIFT_LEFT, KeyCode.Modifier.VK_SHIFT_RIGHT,
                ],
                flag: .shift)
        default:
            return parseTokens(raw)
        }
    }

    private static func parseTokens(_ raw: String) -> ModeShortcut? {
        var tokens = raw.split(
            separator: "+",
            omittingEmptySubsequences: false
        ).map(String.init)
        guard let last = tokens.popLast(), !last.isEmpty else { return nil }

        // A single modifier code with no preceding modifiers is a lone tap.
        if tokens.isEmpty, let lone = loneModifier(forCode: last) {
            return lone
        }

        guard !tokens.isEmpty, let keyCode = w3cToMacKeyCode[last] else {
            return nil
        }

        var modifiers: NSEvent.ModifierFlags = []
        for token in tokens {
            guard let modifier = modifierFlag(forToken: token) else {
                return nil
            }
            guard !modifiers.contains(modifier) else {
                return nil
            }
            modifiers.insert(modifier)
        }

        guard !isReservedShortcut(code: last, modifiers: modifiers) else {
            return nil
        }

        return .combo(keyCode: keyCode, modifiers: modifiers)
    }

    private static func modifierFlag(
        forToken token: String
    ) -> NSEvent.ModifierFlags? {
        switch token.lowercased() {
        case "shift": return .shift
        case "control", "ctrl": return .control
        case "alt", "option": return .option
        case "meta", "command", "cmd": return .command
        default: return nil
        }
    }

    private static func loneModifier(forCode code: String) -> ModeShortcut? {
        switch code {
        case "ShiftLeft":
            return .loneModifier(keyCodes: [KeyCode.Modifier.VK_SHIFT_LEFT], flag: .shift)
        case "ShiftRight":
            return .loneModifier(keyCodes: [KeyCode.Modifier.VK_SHIFT_RIGHT], flag: .shift)
        case "ControlLeft":
            return .loneModifier(keyCodes: [KeyCode.Modifier.VK_CONTROL_LEFT], flag: .control)
        case "ControlRight":
            return .loneModifier(keyCodes: [KeyCode.Modifier.VK_CONTROL_RIGHT], flag: .control)
        case "AltLeft":
            return .loneModifier(keyCodes: [KeyCode.Modifier.VK_OPTION_LEFT], flag: .option)
        case "AltRight":
            return .loneModifier(keyCodes: [KeyCode.Modifier.VK_OPTION_RIGHT], flag: .option)
        case "MetaLeft":
            return .loneModifier(keyCodes: [KeyCode.Modifier.VK_COMMAND_LEFT], flag: .command)
        case "MetaRight":
            return .loneModifier(keyCodes: [KeyCode.Modifier.VK_COMMAND_RIGHT], flag: .command)
        default:
            return nil
        }
    }

    /// True when a key-down event matches this (combo) shortcut. The configured
    /// modifier set must match exactly so unrelated combos don't trigger it.
    func matchesKeyDown(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> Bool {
        guard case let .combo(code, mods) = self else { return false }
        guard keyCode == code else { return false }
        let mask: NSEvent.ModifierFlags = [.shift, .control, .option, .command]
        return modifiers.intersection(mask) == mods
    }

    /// The modifier key(s) and flag for a lone-modifier-tap shortcut, else nil.
    var loneModifierKeys: (keyCodes: Set<UInt16>, flag: NSEvent.ModifierFlags)? {
        guard case let .loneModifier(keyCodes, flag) = self else { return nil }
        return (keyCodes, flag)
    }
}

/// Maps every W3C UI Events `code` accepted by the settings recorder to its
/// macOS virtual key code. Unknown codes are rejected by `ModeShortcut.parse`.
private let w3cToMacKeyCode: [String: UInt16] = [
    "KeyA": KeyCode.Alphabet.VK_A, "KeyB": KeyCode.Alphabet.VK_B,
    "KeyC": KeyCode.Alphabet.VK_C, "KeyD": KeyCode.Alphabet.VK_D,
    "KeyE": KeyCode.Alphabet.VK_E, "KeyF": KeyCode.Alphabet.VK_F,
    "KeyG": KeyCode.Alphabet.VK_G, "KeyH": KeyCode.Alphabet.VK_H,
    "KeyI": KeyCode.Alphabet.VK_I, "KeyJ": KeyCode.Alphabet.VK_J,
    "KeyK": KeyCode.Alphabet.VK_K, "KeyL": KeyCode.Alphabet.VK_L,
    "KeyM": KeyCode.Alphabet.VK_M, "KeyN": KeyCode.Alphabet.VK_N,
    "KeyO": KeyCode.Alphabet.VK_O, "KeyP": KeyCode.Alphabet.VK_P,
    "KeyQ": KeyCode.Alphabet.VK_Q, "KeyR": KeyCode.Alphabet.VK_R,
    "KeyS": KeyCode.Alphabet.VK_S, "KeyT": KeyCode.Alphabet.VK_T,
    "KeyU": KeyCode.Alphabet.VK_U, "KeyV": KeyCode.Alphabet.VK_V,
    "KeyW": KeyCode.Alphabet.VK_W, "KeyX": KeyCode.Alphabet.VK_X,
    "KeyY": KeyCode.Alphabet.VK_Y, "KeyZ": KeyCode.Alphabet.VK_Z,
    "Digit0": KeyCode.Number.VK_KEY_0, "Digit1": KeyCode.Number.VK_KEY_1,
    "Digit2": KeyCode.Number.VK_KEY_2, "Digit3": KeyCode.Number.VK_KEY_3,
    "Digit4": KeyCode.Number.VK_KEY_4, "Digit5": KeyCode.Number.VK_KEY_5,
    "Digit6": KeyCode.Number.VK_KEY_6, "Digit7": KeyCode.Number.VK_KEY_7,
    "Digit8": KeyCode.Number.VK_KEY_8, "Digit9": KeyCode.Number.VK_KEY_9,
    "Backquote": KeyCode.Symbol.VK_BACKQUOTE,
    "Minus": KeyCode.Symbol.VK_MINUS,
    "Equal": KeyCode.Symbol.VK_EQUAL,
    "BracketLeft": KeyCode.Symbol.VK_BRACKET_LEFT,
    "BracketRight": KeyCode.Symbol.VK_BRACKET_RIGHT,
    "Backslash": KeyCode.Symbol.VK_BACKSLASH,
    "Semicolon": KeyCode.Symbol.VK_SEMICOLON,
    "Quote": KeyCode.Symbol.VK_QUOTE,
    "Comma": KeyCode.Symbol.VK_COMMA,
    "Period": KeyCode.Symbol.VK_DOT,
    "Slash": KeyCode.Symbol.VK_SLASH,
    "Space": KeyCode.Special.VK_SPACE,
    "Enter": KeyCode.Special.VK_RETURN,
    "Tab": KeyCode.Special.VK_TAB,
]

private let khiinOptionShortcutCodes: Set<String> = [
    "KeyH", "KeyS", "KeyL", "Space",
]

private let macOSControlTextShortcutCodes: Set<String> = [
    "KeyA", "KeyB", "KeyD", "KeyE", "KeyF", "KeyH", "KeyK", "KeyL",
    "KeyN", "KeyO", "KeyP", "KeyT", "KeyU", "KeyV", "KeyW", "KeyY",
]

private func isReservedShortcut(
    code: String,
    modifiers: NSEvent.ModifierFlags
) -> Bool {
    if modifiers.contains(.option) && khiinOptionShortcutCodes.contains(code) {
        return true
    }
    if modifiers.contains(.command) {
        return true
    }
    if modifiers.contains([.control, .option]) {
        return true
    }
    if modifiers.contains(.control)
        && (code == "Space" || macOSControlTextShortcutCodes.contains(code))
    {
        return true
    }

    return false
}

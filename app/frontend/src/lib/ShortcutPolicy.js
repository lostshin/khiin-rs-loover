/** @typedef {"Control" | "Alt" | "Shift" | "Meta"} ModifierName */

/** @type {readonly ModifierName[]} */
const MODIFIER_ORDER = ["Control", "Alt", "Shift", "Meta"];

export const MODIFIER_CODES = new Set([
    "ShiftLeft",
    "ShiftRight",
    "ControlLeft",
    "ControlRight",
    "AltLeft",
    "AltRight",
    "MetaLeft",
    "MetaRight",
]);

const SUPPORTED_KEY_CODES = new Set([
    ..."ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").map((letter) => `Key${letter}`),
    ..."0123456789".split("").map((digit) => `Digit${digit}`),
    "Backquote",
    "Minus",
    "Equal",
    "BracketLeft",
    "BracketRight",
    "Backslash",
    "Semicolon",
    "Quote",
    "Comma",
    "Period",
    "Slash",
    "Space",
    "Enter",
    "Tab",
]);

const KHIIN_OPTION_CODES = new Set(["KeyH", "KeyS", "KeyL", "Space"]);
const MACOS_CONTROL_TEXT_CODES = new Set([
    "KeyA",
    "KeyB",
    "KeyD",
    "KeyE",
    "KeyF",
    "KeyH",
    "KeyK",
    "KeyL",
    "KeyN",
    "KeyO",
    "KeyP",
    "KeyT",
    "KeyU",
    "KeyV",
    "KeyW",
    "KeyY",
]);

/**
 * @param {ModifierName[]} modifiers
 * @param {string} code
 */
export function createShortcutToken(modifiers, code) {
    const normalizedModifiers = MODIFIER_ORDER.filter((modifier) =>
        modifiers.includes(modifier),
    );
    return [...normalizedModifiers, code].join("+");
}

/**
 * @param {ModifierName[]} modifiers
 * @param {string} code
 * @returns {{ ok: true, token: string } | { ok: false, reason: "unsupported" | "reserved" }}
 */
export function validateShortcut(modifiers, code) {
    if (!SUPPORTED_KEY_CODES.has(code)) {
        return { ok: false, reason: "unsupported" };
    }

    const isReserved =
        (modifiers.includes("Alt") && KHIIN_OPTION_CODES.has(code)) ||
        modifiers.includes("Meta") ||
        (modifiers.includes("Control") && modifiers.includes("Alt")) ||
        (modifiers.includes("Control") &&
            (code === "Space" || MACOS_CONTROL_TEXT_CODES.has(code)));
    if (isReserved) {
        return { ok: false, reason: "reserved" };
    }

    return { ok: true, token: createShortcutToken(modifiers, code) };
}

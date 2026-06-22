// @ts-nocheck
import assert from "node:assert/strict";
import test from "node:test";

import {
    createShortcutToken,
    validateShortcut,
} from "../src/lib/ShortcutPolicy.js";

test("normalizes modifier order", () => {
    assert.equal(
        createShortcutToken(["Meta", "Control", "Shift"], "KeyK"),
        "Control+Shift+Meta+KeyK",
    );
});

test("accepts a supported non-conflicting shortcut", () => {
    assert.deepEqual(validateShortcut(["Control"], "KeyM"), {
        ok: true,
        token: "Control+KeyM",
    });
});

test("rejects an unmapped W3C code", () => {
    assert.deepEqual(validateShortcut(["Control"], "F12"), {
        ok: false,
        reason: "unsupported",
    });
});

test("rejects Khíín output-mode shortcuts", () => {
    for (const [modifiers, code] of [
        [["Alt"], "KeyH"],
        [["Alt", "Shift"], "KeyH"],
        [["Alt"], "KeyS"],
        [["Alt"], "KeyL"],
        [["Alt"], "Space"],
    ]) {
        assert.deepEqual(validateShortcut(modifiers, code), {
            ok: false,
            reason: "reserved",
        });
    }
});

test("rejects macOS and standard app shortcuts", () => {
    for (const [modifiers, code] of [
        [["Meta"], "KeyC"],
        [["Meta"], "KeyB"],
        [["Meta"], "Space"],
        [["Control"], "Space"],
        [["Control", "Alt"], "Space"],
        [["Control", "Alt"], "KeyM"],
        [["Control"], "KeyA"],
        [["Shift", "Meta"], "Digit4"],
    ]) {
        assert.deepEqual(validateShortcut(modifiers, code), {
            ok: false,
            reason: "reserved",
        });
    }
});

test("allows the explicit macOS product default", () => {
    assert.deepEqual(validateShortcut(["Alt"], "Backquote"), {
        ok: true,
        token: "Alt+Backquote",
    });
});

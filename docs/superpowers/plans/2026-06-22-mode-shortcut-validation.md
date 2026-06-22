# Mode Shortcut Validation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reject unsupported and conflicting macOS mode shortcuts and ensure only a genuinely lone physical modifier tap toggles input mode.

**Architecture:** Put recorder validation in a pure TypeScript policy module so it can be unit-tested with Node and consumed by Svelte. Mirror the safety-critical parsing and reserved-combination checks in Swift so stale or manually edited settings cannot bypass the UI. Replace the controller Boolean with a pure Swift physical-key tracker.

**Tech Stack:** Svelte 3, TypeScript, Node 22 test runner, Swift 5.8+, AppKit/InputMethodKit, SwiftPM/XCTest

---

### Task 1: Define and test the frontend shortcut policy

**Files:**
- Create: `app/frontend/src/lib/ShortcutPolicy.ts`
- Create: `app/frontend/src/lib/ShortcutPolicy.test.ts`
- Modify: `app/frontend/package.json`
- Test: `app/frontend/src/lib/ShortcutPolicy.test.ts`

- [ ] **Step 1: Write failing policy tests**

Test these behaviors with `node:test` and `node:assert/strict`:

```ts
import test from "node:test";
import assert from "node:assert/strict";
import {
    createShortcutToken,
    validateShortcut,
} from "./ShortcutPolicy.ts";

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
    assert.deepEqual(validateShortcut(["Alt"], "KeyH"), {
        ok: false,
        reason: "reserved",
    });
});

test("rejects macOS and standard app shortcuts", () => {
    for (const [modifiers, code] of [
        [["Meta"], "KeyC"],
        [["Meta"], "Space"],
        [["Control"], "Space"],
        [["Control", "Alt"], "Space"],
        [["Shift", "Meta"], "Digit4"],
    ] as const) {
        assert.deepEqual(validateShortcut([...modifiers], code), {
            ok: false,
            reason: "reserved",
        });
    }
});
```

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```bash
cd app/frontend
node --test src/lib/ShortcutPolicy.test.ts
```

Expected: failure because `ShortcutPolicy.ts` does not exist.

- [ ] **Step 3: Implement the minimal policy**

Create exports for:

```ts
export type ModifierName = "Control" | "Alt" | "Shift" | "Meta";
export type ShortcutValidation =
    | { ok: true; token: string }
    | { ok: false; reason: "unsupported" | "reserved" };

export const MODIFIER_CODES = new Set([
    "ShiftLeft", "ShiftRight", "ControlLeft", "ControlRight",
    "AltLeft", "AltRight", "MetaLeft", "MetaRight",
]);

export function createShortcutToken(
    modifiers: ModifierName[],
    code: string,
): string;

export function validateShortcut(
    modifiers: ModifierName[],
    code: string,
): ShortcutValidation;
```

The supported-code allowlist must exactly match the Swift W3C map: `KeyA`–`KeyZ`,
`Digit0`–`Digit9`, Backquote, Minus, Equal, BracketLeft, BracketRight,
Backslash, Semicolon, Quote, Comma, Period, Slash, Space, Enter, and Tab.

The reserved set must include:

```ts
[
    "Alt+KeyH", "Alt+KeyS", "Alt+KeyL", "Alt+Space",
    "Control+Space", "Control+Alt+Space",
    "Meta+KeyA", "Meta+KeyC", "Meta+KeyF", "Meta+KeyG",
    "Meta+KeyH", "Meta+KeyM", "Meta+KeyN", "Meta+KeyO",
    "Meta+KeyP", "Meta+KeyQ", "Meta+KeyS", "Meta+KeyT",
    "Meta+KeyV", "Meta+KeyW", "Meta+KeyX", "Meta+KeyZ",
    "Shift+Meta+KeyG", "Shift+Meta+KeyZ",
    "Alt+Meta+KeyH", "Alt+Meta+KeyM", "Alt+Meta+KeyW",
    "Meta+Space", "Alt+Meta+Space", "Control+Meta+Space",
    "Control+Meta+KeyF", "Control+Meta+KeyQ",
    "Meta+Tab", "Meta+Backquote", "Meta+Comma",
    "Shift+Meta+Digit3", "Shift+Meta+Digit4", "Shift+Meta+Digit5",
    "Shift+Meta+KeyQ", "Alt+Shift+Meta+KeyQ",
]
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run:

```bash
cd app/frontend
node --test src/lib/ShortcutPolicy.test.ts
```

Expected: all policy tests pass.

- [ ] **Step 5: Add the repeatable package script**

Add:

```json
"test:shortcuts": "node --test src/lib/ShortcutPolicy.test.ts"
```

to `app/frontend/package.json`.

### Task 2: Reject invalid recordings with localized feedback

**Files:**
- Modify: `app/frontend/src/lib/ShortcutRecorder.svelte`
- Modify: `app/frontend/src/locales/en.json`
- Modify: `app/frontend/src/locales/oan_Han.json`
- Modify: `app/frontend/src/locales/oan_Latn.json`

- [ ] **Step 1: Integrate the tested policy**

Import `MODIFIER_CODES`, `ModifierName`, and `validateShortcut`. Replace the
component-local modifier-code table and token construction with the policy.
When validation fails, keep recording active and set an error translation key.
Only call `finalize` for `{ ok: true }`.

- [ ] **Step 2: Render an accessible error message**

Below the recorder controls, render the current localized error with
`role="alert"` and a red small-text style. Clear the error when recording
starts, succeeds, is canceled, or resets.

- [ ] **Step 3: Add all three locale strings**

Add:

```json
"shortcut-unsupported": "This key can’t be used for this shortcut.",
"shortcut-conflict": "This shortcut is already used by Khíín, macOS, or a common app command."
```

with equivalent Taiwanese Han-character and POJ translations in their
respective locale files.

- [ ] **Step 4: Run frontend checks**

Run:

```bash
cd app/frontend
npm run test:shortcuts
npm run check
npm run build
```

Expected: tests, Svelte type checking, and production build all succeed.

### Task 3: Make Swift parsing reject unknown and reserved combinations

**Files:**
- Create: `swift/osx/Tests/ModeShortcutTests.swift`
- Modify: `swift/osx/src/keys/ModeShortcut.swift`
- Modify: `swift/osx/src/controller/InputController+handler.swift`
- Test: `swift/osx/Tests/ModeShortcutTests.swift`

- [ ] **Step 1: Write failing parser tests**

Cover:

```swift
func testUnknownCodeIsRejected()
func testMalformedModifierIsRejected()
func testCombinationRequiresAModifier()
func testKhiinReservedOptionShortcutIsRejected()
func testMacOSReservedShortcutIsRejected()
func testSupportedShortcutMatchesExactModifiers()
func testDefaultShortcutStillMatchesOptionBackquote()
```

Use `XCTAssertNil(ModeShortcut.parse(...))` for rejected settings and
`XCTAssertTrue`/`XCTAssertFalse` for exact matching.

- [ ] **Step 2: Run focused Swift tests and verify RED**

Run:

```bash
swift test --package-path swift/osx --filter ModeShortcutTests
```

Expected: tests fail because parsing still falls back to Backquote and returns a
non-optional shortcut.

- [ ] **Step 3: Implement strict optional parsing**

Change:

```swift
static func parse(_ raw: String) -> ModeShortcut?
```

Reject unknown modifier names, duplicate modifiers, normal keys without a
modifier, unknown W3C codes, and reserved combinations. Preserve `default`,
empty-string compatibility, `shift`, and supported lone modifier codes.

Mirror the frontend reserved set using normalized token strings. Do not mark
`Alt+Backquote` as reserved because it is the product default.

- [ ] **Step 4: Safely consume optional parsing**

Use optional chaining in the key-down path:

```swift
let changeInputMode = ModeShortcut.parse(self.inputModeShortcut())?
    .matchesKeyDown(keyCode: event.keyCode, modifiers: modifiers) ?? false
```

and unwrap the parsed lone-modifier data in the flags-changed path.

- [ ] **Step 5: Run focused Swift tests and verify GREEN**

Run:

```bash
swift test --package-path swift/osx --filter ModeShortcutTests
```

Expected: all parser tests pass.

### Task 4: Track lone modifiers by physical key

**Files:**
- Create: `swift/osx/src/keys/LoneModifierTapTracker.swift`
- Create: `swift/osx/Tests/LoneModifierTapTrackerTests.swift`
- Modify: `swift/osx/src/controller/InputController.swift`
- Modify: `swift/osx/src/controller/InputController+handler.swift`
- Test: `swift/osx/Tests/LoneModifierTapTrackerTests.swift`

- [ ] **Step 1: Write failing state-machine tests**

Cover:

```swift
func testSinglePhysicalModifierTogglesOnRelease()
func testTwoShiftKeysCancelTheSequence()
func testAnotherModifierCancelsTheSequence()
func testNormalKeyCancelsTheSequence()
func testSideSpecificShortcutIgnoresTheOtherSide()
```

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
swift test --package-path swift/osx --filter LoneModifierTapTrackerTests
```

Expected: compilation fails because the tracker does not exist.

- [ ] **Step 3: Implement the pure tracker**

Create a struct that stores the target key set, currently pressed target keys,
the single armed physical key, and an invalidated flag. Its target-key event
method returns `true` only for the valid final release. Provide `cancel()` and
`reset()` methods for other modifier and normal-key events.

- [ ] **Step 4: Replace the controller Boolean**

Replace `loneModifierArmed` with `loneModifierTapTracker`. In
`handleFlagsChanged`, configure/reset the tracker when the parsed shortcut
changes, send target key transitions into it, cancel on other modifier changes,
and perform the mode toggle only when the tracker returns `true`. Cancel rather
than reset on a real key-down so the eventual modifier release cannot re-arm.

- [ ] **Step 5: Run focused tracker tests and verify GREEN**

Run:

```bash
swift test --package-path swift/osx --filter LoneModifierTapTrackerTests
```

Expected: all tracker tests pass.

### Task 5: Verify the complete change

**Files:**
- Verify all files modified in Tasks 1–4.

- [ ] **Step 1: Run complete frontend and Swift checks**

Run:

```bash
cd app/frontend
npm run test:shortcuts
npm run check
npm run build
cd ../../
swift test --package-path swift/osx
```

Expected: all commands succeed with zero test failures.

- [ ] **Step 2: Validate locale JSON and whitespace**

Run:

```bash
node -e 'for (const f of process.argv.slice(1)) JSON.parse(require("fs").readFileSync(f, "utf8"))' app/frontend/src/locales/en.json app/frontend/src/locales/oan_Han.json app/frontend/src/locales/oan_Latn.json
git diff --check
```

Expected: both commands exit successfully.

- [ ] **Step 3: Review only scoped changes**

Run:

```bash
git diff HEAD -- app/frontend/src/lib/ShortcutPolicy.ts app/frontend/src/lib/ShortcutPolicy.test.ts app/frontend/src/lib/ShortcutRecorder.svelte app/frontend/package.json app/frontend/src/locales/en.json app/frontend/src/locales/oan_Han.json app/frontend/src/locales/oan_Latn.json swift/osx/src/keys/ModeShortcut.swift swift/osx/src/keys/LoneModifierTapTracker.swift swift/osx/src/controller/InputController.swift swift/osx/src/controller/InputController+handler.swift swift/osx/Tests/ModeShortcutTests.swift swift/osx/Tests/LoneModifierTapTrackerTests.swift
```

Expected: the diff contains only validation, conflict feedback, strict parsing,
physical-key tracking, and their tests.

# Mode Shortcut Validation Design

## Goal

Make the macOS input-mode shortcut recorder accept only combinations that the
IME can execute safely, reject known Khíín, macOS, and common application
shortcut conflicts, and correctly recognize a genuinely lone modifier tap.

## Root Causes

The settings recorder accepts every W3C `KeyboardEvent.code`, while the Swift
parser maps only a subset. An unknown code currently falls back to Backquote,
so the stored shortcut and executed shortcut can differ.

The IME also has built-in Option shortcuts for output-mode changes. Those
handlers run before the configurable input-mode shortcut, so a conflicting
configuration performs the built-in action instead.

Finally, lone Shift is represented by both physical Shift key codes but tracked
with one Boolean. Pressing both Shift keys can therefore re-arm the Boolean
while one key remains down and toggle on the final release.

## Approaches Considered

### Selected: Allowlist plus reserved shortcuts at both boundaries

Define a pure frontend shortcut-policy module containing:

- the W3C key codes that Swift can map;
- normalized modifier ordering;
- Khíín built-in reserved combinations;
- macOS default system combinations;
- common application-standard combinations.

The recorder consults this policy before saving. Unsupported or reserved
combinations remain unsaved, display a localized explanation, and leave the
recorder active so the user can immediately try another shortcut.

Swift independently rejects malformed, unmapped, and reserved settings. This
protects the IME from stale or manually edited `settings.toml` values. Default
`Option+Backquote` remains valid because it is the product default; the
equivalent explicitly recorded value is also valid.

### Rejected: Frontend-only validation

This gives immediate feedback but can be bypassed by existing settings,
manually edited configuration, or a future settings client.

### Rejected: Dynamically enumerate every macOS and application shortcut

macOS exposes some configurable system shortcuts, but not a reliable global
registry for every application. Dynamic enumeration would still be incomplete
and would add platform-specific settings plumbing. The product will instead
block a documented conservative set of defaults without claiming to detect
arbitrary application customizations.

## Conflict Policy

The recorder rejects:

- Khíín output-mode shortcuts: `Option+H`, `Option+S`, `Option+L`, and
  `Option+Space`.
- macOS navigation and system defaults such as application/window switching,
  Spotlight, input-source switching, Mission Control/Spaces, screenshots,
  Force Quit, Lock Screen, log out, Hide, and Minimize.
- common application operations such as Select All, Copy, Paste, Cut, Undo,
  Redo, New, Open, Close, Save, Print, Find, Find Next, Preferences, and Quit.

The list is based on physical W3C codes and normalized modifiers. Exact matches
are rejected; adding an unrelated modifier does not collide unless that exact
combination is also reserved.

## Lone Modifier Tracking

Replace the controller Boolean with a small state tracker that records which
physical target modifier keys are currently held and whether the current
sequence remains eligible. A second target modifier, any other modifier, or a
normal key invalidates the sequence. Toggling occurs only when the same single
physical key that armed the sequence is released and no target key remains
held.

The tracker is pure Swift and receives press/release facts from the controller,
which makes the two-Shift regression independently testable.

## Testing

- Node's built-in test runner exercises the pure frontend policy without adding
  a new test framework.
- XCTest verifies unknown-code rejection, reserved-combination rejection,
  supported parsing, exact modifier matching, and the lone-modifier state
  machine.
- `svelte-check`, the frontend build, and the complete Swift test suite verify
  integration.

## Non-goals

- Detecting user-defined shortcuts in every installed application.
- Changing Windows shortcut behavior or its settings UI.
- Reassigning Khíín's existing output-mode shortcuts.
- Allowing unmodified typing keys as mode shortcuts.

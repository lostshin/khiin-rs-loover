# Candidate Shortcut Labels Design

## Goal

Make the macOS candidate menu show shortcut numbers `1.` through `9.` as soon
as candidates appear, matching the number keys that select those candidates.

## Root Cause

The Rust engine uses one-based keyboard selection: key `1` selects page-local
index 0, key `7` selects index 6, and key `9` selects index 8. The macOS view
passes page-local indexes 0 through 8 directly to the label and hides index 0.
Consequently, index 6 is displayed as `6.` even though key `7` selects it.

## Approaches Considered

### Selected: Always render one-based page-local labels

Keep focus and candidate indexes zero-based internally. Convert only the visual
shortcut label to `index + 1`, and render it unconditionally for every visible
candidate. Every page therefore displays `1.` through `9.` and remains aligned
with the engine's number-key mapping.

### Rejected: Show labels only after entering selection state

This would correct the offset but would not satisfy the requirement that
numbers appear as soon as the candidate menu opens.

### Rejected: Revert the engine to zero-based number keys

That would make key `1` select the second candidate and conflict with standard
IME behavior and the existing engine fix.

## Implementation

Add a small pure Swift helper that converts page-local indexes to display
labels. `CandidateItem` uses the helper without a focus-dependent condition.
Focus highlighting remains zero-based and unchanged.

Add a SwiftPM test target with a focused unit test proving indexes 0 through 8
produce labels `1.` through `9.`. Run the existing Rust tests and Swift tests,
then rebuild and inspect the 0.3.6 release package for user testing.

## Non-goals

- Changing candidate order or paging.
- Changing number-key behavior in the Rust engine.
- Changing Windows, Android, or iOS candidate UI.
- Changing candidate font, spacing, or colors.

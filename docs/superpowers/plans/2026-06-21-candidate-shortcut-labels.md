# Candidate Shortcut Labels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Display one-based shortcut labels `1.` through `9.` on every visible macOS candidate as soon as the candidate window opens.

**Architecture:** Keep candidate and focus indexes zero-based. Add a pure Swift formatter at the macOS candidate-view boundary, test it through the existing executable module, and render its result unconditionally without changing selection behavior.

**Tech Stack:** Swift 5.8, SwiftUI, Swift Package Manager/XCTest, Rust/cargo-make

---

### Task 1: Add and use one-based candidate shortcut labels

**Files:**
- Create: `swift/osx/Tests/CandidateShortcutLabelTests.swift`
- Create: `swift/osx/src/candidates/CandidateShortcutLabel.swift`
- Modify: `swift/osx/Package.swift`
- Modify: `swift/osx/src/candidates/CandidateView.swift`
- Test: `swift/osx/Tests/CandidateShortcutLabelTests.swift`

- [ ] **Step 1: Register a SwiftPM test target and write the failing test**

Add `KhiinPJHTests` to `swift/osx/Package.swift`, depending on `KhiinPJH` with path `Tests`, then create:

```swift
import XCTest
@testable import KhiinPJH

final class CandidateShortcutLabelTests: XCTestCase {
    func testPageLocalIndexesUseOneBasedShortcutLabels() {
        let labels = (0...8).map { candidateShortcutLabel(for: $0) }

        XCTAssertEqual(labels, ["1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9."])
    }
}
```

- [ ] **Step 2: Run the focused Swift test and verify RED**

Run:

```bash
swift test --package-path swift/osx --filter CandidateShortcutLabelTests
```

Expected: compilation fails because `candidateShortcutLabel(for:)` does not exist.

- [ ] **Step 3: Add the minimal pure formatter**

Create `swift/osx/src/candidates/CandidateShortcutLabel.swift`:

```swift
func candidateShortcutLabel(for index: Int) -> String {
    "\(index + 1)."
}
```

- [ ] **Step 4: Run the focused Swift test and verify GREEN**

Run:

```bash
swift test --package-path swift/osx --filter CandidateShortcutLabelTests
```

Expected: one test passes with zero failures.

- [ ] **Step 5: Render the formatter result unconditionally**

Replace the focus-dependent label block in `CandidateItem` with:

```swift
Text(candidateShortcutLabel(for: index))
    .frame(minWidth: 16)
```

Leave both `index == focus` highlight expressions unchanged.

- [ ] **Step 6: Run the complete Swift and Rust test suites**

Run:

```bash
swift test --package-path swift/osx
export PATH="$HOME/.cargo/bin:$PATH"
cargo make test
```

Expected: all Swift and Rust tests pass with zero failures.

- [ ] **Step 7: Build and inspect the release package**

Run:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
cargo make --profile release build-osx
PACKAGE=swift/osx/.build/artifacts/release/KhiinPJH-0.3.6.pkg
test -f "$PACKAGE"
pkgutil --payload-files "$PACKAGE" | rg 'Contents/MacOS/KhiinPJH$'
```

Expected: the release build exits successfully, the `0.3.6` package exists, and its payload contains the `KhiinPJH` executable.

- [ ] **Step 8: Review and commit the scoped changes**

Run:

```bash
git diff --check
git diff -- swift/osx/Package.swift swift/osx/src/candidates/CandidateView.swift swift/osx/src/candidates/CandidateShortcutLabel.swift swift/osx/Tests/CandidateShortcutLabelTests.swift docs/superpowers/plans/2026-06-21-candidate-shortcut-labels.md
git add docs/superpowers/plans/2026-06-21-candidate-shortcut-labels.md swift/osx/Package.swift swift/osx/src/candidates/CandidateView.swift swift/osx/src/candidates/CandidateShortcutLabel.swift swift/osx/Tests/CandidateShortcutLabelTests.swift
git commit --no-gpg-sign -m "fix: show one-based candidate shortcuts" -m "Co-Authored-By: OpenAI Codex <noreply@openai.com>"
```

Expected: only the plan, SwiftPM manifest, formatter, view, and focused test are committed.

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Khíín is a cross-platform Taiwanese (Hō-ló / Tâi-gí) input method (IME). The design is **one Rust engine + thin per-platform shells**. The engine is platform-agnostic; each platform (macOS, iOS, Windows, Android, CLI, desktop settings app) is a shell that talks to the same engine over a single function passing serialized protobuf bytes.

## Build & dev commands

All tasks are defined in `Makefile.toml` and run via **cargo-make** (required: `cargo install --force cargo-make`). Run from the repo root. List everything with `cargo make --list-all-steps`.

```bash
cargo make build-cli      # build the terminal IME
cargo make run            # build + run the terminal IME (fastest way to exercise the engine)
cargo make build-db       # generate resources/khiin.db from data/data/*.csv (only if missing)
cargo make rebuild-db     # force-regenerate the db after editing the CSV word lists
cargo make test           # run engine unit tests (cargo test on khiin/Cargo.toml)
cargo make format         # rustfmt (uses the nightly toolchain)
cargo make build          # platform default: db + cli, plus the host platform's IME
```

**Running a single test:** `cargo make test` shells out to `cargo test --manifest-path=khiin/Cargo.toml`, so target a single test the normal way:
```bash
cargo test --manifest-path=khiin/Cargo.toml it_handles_send_key_commands
```

**Critical: tests and the CLI need `target/debug/khiin.db` to exist.** The test harness (`khiin/src/tests/mod.rs`) loads the db from `target/debug/khiin.db`, and `cargo make test` does **not** depend on building it. On a fresh checkout you must first produce it:
```bash
cargo make build-db && cargo make copy-db   # or: cargo make build-common
```
Otherwise `Engine::new` returns `None` and every engine test fails.

### Per-platform builds (each runs only on its host OS)
- **macOS IME:** `cargo make build-osx` — builds the swift-bridge `.a` for all Apple targets, builds the Swift input method, **installs it to `~/Library/Input Methods/`**, and runs `pkgbuild` to emit `swift/osx/.build/artifacts/<debug|release>/KhiinPJH-*.pkg`. Add `--profile release` for a release build/package.
- **macOS dev loop:** `cargo make build-osx` once, then `cargo make watch-osx` to auto-rebuild on Swift changes. Logs: `tail -f ~/Library/Caches/KhiinPJH/khiin_im.log`.
- **Windows:** `cargo make build-win32` (TSF DLL + engine manager service).
- **Android:** `cargo make build-droid` (copies db into app assets; app is built in Android Studio / Gradle).
- **iOS:** `cargo make xcodegen` to generate `swift/ios/Khiin.xcodeproj`, then build in Xcode.
- **Settings app:** `cargo make tauri-dev` (Tauri v1 + Svelte).

## Architecture

### The single entry point
Everything funnels through `Engine::send_command_bytes(bytes: &[u8]) -> Vec<u8>` in `khiin/src/engine.rs`. Both input and output are a serialized `khiin_protos::Command` protobuf containing a `Request` and a `Response`. `send_command_bytes` is one big `match` over `CommandType` dispatching to `on_*` handlers. **Many `CommandType` handlers are still `Err("Not implemented")`** (e.g. `on_revert`, `on_select_candidate`, `on_list_emojis`, `on_reset_user_data`) — this is the live backlog. To add engine behavior you almost always edit one of these handlers.

### The protobuf contract (`protos/src/*.proto`)
`command.proto` and `config.proto` are the contract between engine and every shell. Key messages: `Request` (carries a `KeyEvent` + `AppConfig`), `Response` (`Preedit` segments + `CandidateList` + `EditState` + committed text). When you change a `.proto`:
- **Rust side regenerates automatically** via `protos/build.rs` on the next `cargo build`.
- **Swift side does NOT** — you must run `cargo make build-swift-protos` (invokes `protoc`) to regenerate `swift/shared/src/protos/*.pb.swift`. Forgetting this is a common source of engine/shell field mismatches.

### Inside the engine
`Engine` holds a `BufferMgr` (stateful edit buffer: preedit, candidate paging/focus, edit-state machine — see `khiin/src/buffer/buffer_mgr.rs`) and an `EngInner { Database, Dictionary, Config }`. Candidate search is two-step: first segment the raw input using word-list probabilities (`khiin/src/data/segmenter.rs`), then look up each segment in the conversion table and rank with unigram/bigram weights. Romaji→syllable→key-sequence parsing lives in `khiin/src/input/`.

Three input modes (`Continuous`, `Classic`, `Manual`) significantly change key semantics throughout `on_send_key` and the shells — always account for all three when touching key handling.

### Data / database
`data/data/*.csv` (`conversions_all.csv`, `frequency.csv`, `emoji.csv`, provided by Tâi Jī Siā) are compiled into the SQLite `resources/khiin.db` by the `khiin/dbgen` tool. Edit CSVs → `cargo make rebuild-db`. The db is also updated with user n-gram data during use.

### Workspace crates and shells
- `khiin` — the engine. `khiin/dbgen` — db generator CLI.
- `khiin_ji` (`ji/`) — pure, stateless Taiwanese text library: lomaji (romanization), tone, unicode normalization, punctuation.
- `khiin_protos` (`protos/`) — generated protobuf types.
- `khiin_data` (`data/`) — embedded CSV data.
- Shells: `cli/` (terminal), `swift/osx` (macOS IMKit) + `swift/bridge` (`khiin_swift`, the swift-bridge glue) + `swift/shared` (Swift wrapper around the bridge), `swift/ios`, `windows/ime` (TSF) + `windows/service`, `android/rust` (`khiin_droid`, JNI) + `android/app` (Compose), `app/src-tauri` (`khiin_helper`, the settings app) + `app/frontend` (Svelte).

## Non-obvious gotchas
- **`watch-osx` only runs `swift build`; it does NOT rebuild the Rust bridge.** After changing engine or `swift/bridge` code, rerun `cargo make build-osx` (or `build-swift-bridge`) before the Swift side picks it up.
- **The Apple swift-bridge build (`swift/bridge/build.sh`) always compiles iOS targets too**, even when you only want macOS — all five Apple `rustup` targets must be installed or it fails mid-build.
- **`build-osx` always installs into `~/Library/Input Methods/`**; there is no build-only variant. A release build will overwrite whatever (debug) version you currently have installed.
- **The macOS version is single-sourced** as `version=` at the top of `swift/osx/build.sh`; it feeds `pkgbuild` and stamps the bundle Info.plist. The asset `Info.plist`, `Makefile.toml`, `tauri.conf.json` still carry a stale `0.1.0` placeholder — bump the `build.sh` var per release.
- **The settings app (`khiin_helper`) is the macOS pkg's bundled helper.** It is a Tauri v1 app; `app/src-tauri/icons/` is not checked in, so a first `cargo tauri build` fails with "Failed to create app icon" until you run `cargo tauri icon app/frontend/static/app-icon.png`.
- **cargo/cargo-make are not on the non-interactive shell PATH** — prefix shell commands with `export PATH="$HOME/.cargo/bin:$PATH"`.
- Platform status (per README): Windows is the most complete; macOS/iOS and Android are in progress / unstable.

## macOS IME: install & input-source registration (read before touching `swift/osx`)

These cost hours to rediscover — start here when an installed Khíín won't appear or Settings won't open.

- **"Khíín is missing from Input Sources" is almost always TIS state, not the bundle.** macOS only rebuilds its Text Input Source DB at login. Two modes:
  1. *Fresh install not enumerated* — bundle is copied to `~/Library/Input Methods/` but never registered. Handled: the app calls `TISRegisterInputSource(Bundle.main.bundleURL)` on launch (`src/KhiinIMApp.swift`), and `assets/scripts/postinstall` `open`s it once.
  2. *Upgrade "phantom enabled"* — replacing an existing bundle makes TIS report `IsEnabled == true` while it is NOT in `AppleEnabledInputSources`/`AppleSelectedInputSources`, hiding it from both the "+" add list and the menu. `TISDisableInputSource`/`TISEnableInputSource` silently no-op; **only logout/login (or reboot) clears it.** Every rebuild that replaces the bundle needs one logout/login on macOS 26.x — tell the user instead of looping.
- **Dead ends already ruled out — do not re-investigate:** ad-hoc signing / no Developer ID still *enables* fine on macOS 26 (a known-good 0.3.0 was ad-hoc); `TISIntendedLanguage = taioanese` is non-standard but works. Developer ID + notarization matters only for clean Gatekeeper *distribution*, not for the source appearing/enabling.
- **Diagnose without the GUI:** `defaults read com.apple.HIToolbox AppleEnabledInputSources` (live, authoritative) vs the TIS `IsEnabled` flag (`TISCreateInputSourceList`) — a mismatch is the phantom state. Also `codesign -dv --verbose=2 <app>` and `…/Support/lsregister -dump | grep app.khiin` (watch for two paths under one bundle id).
- **`build-osx` does NOT build the helper** — it only copies `target/universal-apple-darwin/<debug|release>/bundle/macos/khiin_helper.app` if present, else ships an IME with no Settings. Build it first: `cd app && cargo tauri build --target universal-apple-darwin [--debug]`.
- **Launch the helper via `NSWorkspace`, never by exec'ing its binary.** A `LSBackgroundOnly` IME that spawns the Tauri/WebKit helper as a child process hangs. See `openSettingApp()` in `src/controller/InputController.swift`.
- **`build.sh` re-signs the bundle ad-hoc** (helper first, then app) because the swift/lipo output is only linker-adhoc with an unsealed Info.plist + wrong identifier, which recent macOS rejects. The IME menu's top row shows `version + build time` so builds are distinguishable.

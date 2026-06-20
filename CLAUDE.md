# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

Khíín is a cross-platform Taiwanese (Hō-ló / Tâi-gí) input method (IME). Design: **one Rust engine + thin per-platform shells**. The engine is platform-agnostic; each shell (macOS, iOS, Windows, Android, CLI, desktop settings app) talks to it over a single function passing serialized protobuf bytes.

## Build & dev commands

All tasks live in `Makefile.toml`, run via **cargo-make** (`cargo install --force cargo-make`). Run from repo root; `cargo make --list-all-steps` lists everything. **cargo/cargo-make are NOT on the non-interactive shell PATH** — prefix with `export PATH="$HOME/.cargo/bin:$PATH"`.

```bash
cargo make run            # build + run the terminal IME (fastest way to exercise the engine)
cargo make build-cli      # build the terminal IME
cargo make rebuild-db     # force-regen resources/khiin.db after editing data/data/*.csv
cargo make test           # engine unit tests (cargo test on khiin/Cargo.toml)
cargo make format         # rustfmt (nightly toolchain)
```

Single test: `cargo test --manifest-path=khiin/Cargo.toml <test_name>`.

**Tests + CLI need `target/debug/khiin.db`.** The harness (`khiin/src/tests/mod.rs`) loads it from there, but `cargo make test` does NOT build it. Fresh checkout: `cargo make build-db && cargo make copy-db` (or `build-common`) — else `Engine::new` returns `None` and all engine tests fail.

### Per-platform builds (each runs only on its host OS)
- **macOS IME:** `cargo make build-osx` — builds swift-bridge `.a` for all Apple targets, builds the Swift IME, **installs to `~/Library/Input Methods/`**, runs `pkgbuild` → `swift/osx/.build/artifacts/<debug|release>/KhiinPJH-*.pkg`. `--profile release` for release.
- **macOS dev loop:** `build-osx` once, then `cargo make watch-osx`. Logs: `tail -f ~/Library/Caches/KhiinPJH/khiin_im.log`.
- **Windows:** `cargo make build-win32`. **Android:** `cargo make build-droid`. **iOS:** `cargo make xcodegen` → build in Xcode.
- **Settings app:** see its own section below.

## Architecture

**Single entry point:** everything funnels through `Engine::send_command_bytes(&[u8]) -> Vec<u8>` in `khiin/src/engine.rs` — one big `match` over `CommandType` dispatching to `on_*` handlers. **Many handlers are still `Err("Not implemented")`** (`on_revert`, `on_select_candidate`, `on_list_emojis`, `on_reset_user_data`) — the live backlog; adding engine behavior usually means editing one.

**Protobuf contract (`protos/src/*.proto`):** `command.proto` + `config.proto` are the contract between engine and every shell (`Request` = `KeyEvent` + `AppConfig`; `Response` = `Preedit` + `CandidateList` + `EditState` + committed text). On change: **Rust regenerates via `protos/build.rs` on next `cargo build`; Swift does NOT** — run `cargo make build-swift-protos` (protoc) to regen `swift/shared/src/protos/*.pb.swift`. Forgetting this silently mismatches fields.

**Inside the engine:** `Engine` holds a `BufferMgr` (stateful edit buffer — `khiin/src/buffer/buffer_mgr.rs`) + `EngInner { Database, Dictionary, Config }`. Candidate search: segment raw input by word-list probabilities (`khiin/src/data/segmenter.rs`), look up each segment, rank by unigram/bigram. Romaji→syllable→key parsing in `khiin/src/input/`. **Three input modes (`Continuous`, `Classic`, `Manual`) change key semantics throughout `on_send_key` — account for all three when touching key handling.**

**Data:** `data/data/*.csv` (Tâi Jī Siā) → SQLite `resources/khiin.db` via `khiin/dbgen`. Edit CSV → `cargo make rebuild-db`. Db also accrues user n-gram data at runtime.

**Workspace:** `khiin` (engine) + `khiin/dbgen`; `khiin_ji` (`ji/`, stateless lomaji/tone/unicode); `khiin_protos` (`protos/`); `khiin_data` (`data/`). Shells: `cli/`, `swift/{osx,bridge,shared,ios}`, `windows/{ime,service}`, `android/{rust,app}`, `app/` (settings).

## Settings app (`khiin_helper`, `app/`) — Tauri **v2** + SvelteKit

The macOS pkg's bundled settings helper. **Frontend (`app/frontend`, Svelte 3 + Tailwind) is SHARED by macOS AND Windows** — a change affects both unless you gate it.

- **Migrated v1 → v2 on 2026-06-20** (tauri-cli 2.11.3). invoke import is `@tauri-apps/api/core` (NOT `/tauri`); conf (`app/src-tauri/tauri.conf.json`) is v2 schema (top-level `identifier`/`productName`, `app`, `bundle`, `devUrl`, `frontendDist`). Backend `app/src-tauri/src/main.rs` exposes 4 commands: `load_settings`, `update_settings`, `is_windows`, `app_version`.
- **Dev:** `cd app && cargo tauri dev` (or `cargo make tauri-dev`). **CLI must be v2** — `Makefile.toml`'s `install-tauri-cli` is pinned to `'^2'`; an unpinned `cargo install tauri-cli` grabs latest, and a version-mismatched CLI fails with `tauri.conf.json` schema errors (`"identifier" is a required property` / unexpected `devPath`).
- **v2 runs `beforeDevCommand` in the frontend dir (`app/frontend`)**, so conf uses `npm run dev` — NOT v1's `npm run --prefix frontend dev` (which under v2 → ENOENT `app/frontend/frontend/package.json`).
- **macOS-only UI redesign:** restructured for macOS only, gated by `isMac` (`app/frontend/src/lib/platform.ts`, derived from `is_windows`). macOS nav = 一般/輸入/按鍵/關於 (System-Settings-style grouped cards via `SettingsGroup`/`SettingsRow`, "已套用" `Toast`). **Windows keeps its original markup in each page's `{:else}` branch — do not touch it.** Telex 9-key remap is its own `/keys` route (macOS); `/input` hides it on macOS.
- **i18n: 3 locales `en` / `oan_Han` / `oan_Latn`** (`app/frontend/src/locales/`, `fallbackLocale: "en"`). Add every new string to all three. **`oan_Latn.json` POJ uses Unicode combining chars — Edit string-match fails on NFC/NFD mismatch; anchor on ASCII-only lines** (e.g. `"appearance": {`, `"github": "GitHub"`). Validate: `node -e "JSON.parse(require('fs').readFileSync('f','utf8'))"`.
- **`build-osx` does NOT build the helper** — build it first: `cd app && cargo tauri build --target universal-apple-darwin [--debug]`. `build-osx` then copies `target/universal-apple-darwin/<debug|release>/bundle/macos/khiin_helper.app` (else ships an IME with no Settings).
- **Launch the helper via `NSWorkspace`, never by exec'ing its binary** — a `LSBackgroundOnly` IME spawning the WebKit helper as a child hangs. See `openSettingApp()` in `swift/osx/src/controller/InputController.swift`.
- **Icons not checked in:** first `cargo tauri build` fails "Failed to create app icon" until `cargo tauri icon app/frontend/static/app-icon.png`.
- **macOS pkg packaging re-verified under v2 on 2026-06-20 (0.3.4):** full `build-osx` → `pkgbuild` produces `KhiinPJH-0.3.4.pkg` with the v2 helper inside (`khiin_helper.app`, `CFBundleVersion=0.3.4` — v2 uses semver, not v1's timestamp). Ad-hoc re-sign OK (outer `KhiinPJH.app` sealed + `app.khiin.inputmethod.khiin`, helper `app.khiin`); install to `~/Library/Input Methods/` registers cleanly (single Launch Services path, no phantom) and the TIS live list reports it `enabled=YES`. `tauri-plugin-shell`'s `plugin:shell|open` permission is baked into the helper binary, so GitHub links are wired — but the actual click→open was only verified statically, not clicked. pkg is still **unsigned** (`pkgbuild` no `--sign`): fine for local install, needs codesign + notarize for distribution.

## Versions (two sources — keep in sync per release)
- **macOS IME pkg:** `version=` atop `swift/osx/build.sh` (feeds `pkgbuild` + IME Info.plist).
- **Settings helper:** `app/src-tauri/Cargo.toml` + `tauri.conf.json` (now `0.3.4`), shown on **Settings → About** via `app_version` = `env!("CARGO_PKG_VERSION")` — **never hardcode a version in the Svelte UI.** Asset `Info.plist` + `Makefile.toml` may lag at `0.1.0`; bump per release.

## Non-obvious gotchas
- **`watch-osx` only runs `swift build`; does NOT rebuild the Rust bridge** — after engine/`swift/bridge` changes, rerun `cargo make build-osx` (or `build-swift-bridge`).
- **swift-bridge build (`swift/bridge/build.sh`) always compiles iOS targets too** — all five Apple `rustup` targets must be installed or it fails mid-build.
- **`build-osx` always installs into `~/Library/Input Methods/`** (no build-only variant); a release build overwrites an installed debug one.
- Platform status (README): Windows most complete; macOS/iOS/Android in progress / unstable.

## macOS IME: install & TIS registration (read before touching `swift/osx`)

These cost hours — start here when an installed Khíín won't appear or Settings won't open.

- **"Khíín missing from Input Sources" is almost always TIS state, not the bundle.** macOS rebuilds its Text Input Source DB only at login. Two modes: (1) *fresh install not enumerated* — handled: app calls `TISRegisterInputSource(Bundle.main.bundleURL)` on launch (`src/KhiinIMApp.swift`) + `assets/scripts/postinstall` `open`s it once; (2) *upgrade "phantom enabled"* — replacing a bundle can make TIS report `IsEnabled==true` while hidden from the "+" list/menu; enable/disable then no-op and **only logout/login clears it.**
- **Diagnose via the TIS live menu list — the ONLY authority.** Throwaway Swift: `TISCreateInputSourceList(nil, false)` returns the *enabled* sources the menu shows; if `app.khiin.inputmethod.khiin` is in it, the IME is genuinely usable — no phantom, no logout needed. **Do NOT trust `defaults read com.apple.HIToolbox AppleEnabledInputSources`** — on macOS 26.x it's a lagging on-disk snapshot that omits enabled sources, so a miss there is NOT evidence of trouble. **Verify with the live list before ever telling the user to log out.** Also: `codesign -dv --verbose=2 <app>`; `…/Support/lsregister -dump | grep app.khiin` (watch for two paths under one bundle id).
- **Dead ends already ruled out — don't re-investigate:** ad-hoc signing / no Developer ID still *enables* fine on macOS 26 (a known-good 0.3.0 was ad-hoc); `TISIntendedLanguage = taioanese` is non-standard but works. Developer ID + notarization matters only for Gatekeeper *distribution*, not appearing/enabling.
- **`build.sh` re-signs the bundle ad-hoc** (helper then app) because swift/lipo output is linker-adhoc with an unsealed Info.plist + wrong identifier, which recent macOS rejects. The IME menu's top row shows `version + build time` so builds are distinguishable.

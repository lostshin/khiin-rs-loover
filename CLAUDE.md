# CLAUDE.md

Guidance for Claude Code in this repo. **Current version: 0.3.6.**

## What this is

Khíín = cross-platform Taiwanese (Hō-ló / Tâi-gí) IME. Design: **one Rust engine + thin per-platform shells**; every shell (macOS, iOS, Windows, Android, CLI, settings app) talks to the engine via one function passing serialized protobuf bytes.

## Working rules (read first)

- **Commit straight to `master` — no feature branches** (user preference). Stage only the files you changed; **never `git add -A`** (it grabs the 20–37 MB root `*.pkg`). `commit.gpgsign` is on → use `git commit --no-gpg-sign` (non-interactive otherwise dies `No pinentry`). End messages with the `Co-Authored-By` trailer. Push only when asked.
- **cargo/cargo-make are NOT on Claude's Bash-tool PATH** — prefix every cargo command: `export PATH="$HOME/.cargo/bin:$PATH"`. (If the *user's own terminal* can't find cargo, a `~/.zshrc` line reset PATH after `~/.zshenv`; fix once by appending `. "$HOME/.cargo/env"` to the rc — don't re-diagnose.)
- Run cargo-make from **repo root** (`cargo make build-osx` from `app/` → "Task not found").
- gitignored: `*.pkg`, `resources/khiin.db`, `target/`, `app/build/`, `app/src-tauri/gen/schemas`, `**/.impeccable/`.

## Build & dev

```bash
cargo make run          # build + run terminal IME (fastest way to exercise the engine)
cargo make test         # engine unit tests (cargo test on khiin/Cargo.toml)
cargo make rebuild-db   # regen resources/khiin.db after editing data/data/*.csv
cargo make format       # rustfmt (nightly)
```
Single test: `cargo test --manifest-path=khiin/Cargo.toml <name>`.
**Tests/CLI need `target/debug/khiin.db`, but `cargo make test` does NOT build it.** Fresh checkout: `cargo make build-db && cargo make copy-db` (or `build-common`), else `Engine::new`→`None` and every engine test fails.

### Per-platform (each runs only on its host OS)
- **macOS IME:** `cargo make build-osx` — builds swift-bridge `.a` (**all 5 Apple `rustup` targets must be installed**, it always compiles iOS too), builds the Swift IME, **installs to `~/Library/Input Methods/`**, pkgbuilds `swift/osx/.build/artifacts/<debug|release>/KhiinPJH-<v>.pkg`. `--profile release` for release (overwrites an installed debug build).
- **macOS dev loop:** `build-osx` once → `cargo make watch-osx` (runs only `swift build`; does **NOT** rebuild the Rust bridge — rerun `build-osx` / `build-swift-bridge` after engine or `swift/bridge` edits). Logs: `~/Library/Caches/KhiinPJH/khiin_im.log`.
- **Windows:** `build-win32`. **Android:** `build-droid`. **iOS:** `xcodegen` → build in Xcode.

## Architecture

- **Single entry point:** `Engine::send_command_bytes(&[u8]) -> Vec<u8>` (`khiin/src/engine.rs`) — one `match` over `CommandType` → `on_*` handlers. Several are still `Err("Not implemented")` (`on_revert`, `on_select_candidate`, `on_list_emojis`, `on_reset_user_data`) = the live backlog.
- **Protobuf contract** (`protos/src/*.proto`, `command.proto` + `config.proto`): `Request` = `KeyEvent` + `AppConfig`; `Response` = `Preedit` + `CandidateList` + `EditState` + committed text. On change Rust auto-regens via `protos/build.rs`; **Swift does NOT — run `cargo make build-swift-protos`** or fields silently mismatch.
- **Engine internals:** `Engine` = `BufferMgr` (`khiin/src/buffer/buffer_mgr.rs`) + `EngInner { Database, Dictionary, Config }`. Candidate search: segment raw input by word-list probability (`data/segmenter.rs`), look up each segment, rank by uni/bigram. Romaji→syllable→key parsing in `khiin/src/input/`. **3 input modes (Continuous / Classic / Manual) change key semantics throughout `on_send_key` — handle all three.**
- **Data:** `data/data/*.csv` (Tâi Jī Siā) → SQLite `resources/khiin.db` via `khiin/dbgen`; edit CSV → `rebuild-db`. Db also accrues user n-gram data at runtime.
- **Workspace:** `khiin` (engine) + `khiin/dbgen`; `khiin_ji` (`ji/`, stateless lomaji/tone/unicode); `khiin_protos` (`protos/`); `khiin_data` (`data/`). Shells: `cli/`, `swift/{osx,bridge,shared,ios}`, `windows/{ime,service}`, `android/{rust,app}`, `app/` (settings).

## Performance — candidate lookups MUST hit an index (fixed in 0.3.6)

- **Symptom:** typing laggy. **Real cause is the engine DB, not the UI.** `conversion_lookups` is a VIEW (`key_sequences ⋈ inputs ⋈ conversions`) filtered by `key_sequence`; the only `key_sequences` indexes (`input_numeric/telex_covering_index`) reference **columns that no longer exist**, so the planner did a full `SCAN` of ~182k rows several times per keystroke (25–80 ms/key, worse as the buffer grows).
- **Fix shipped:** migration `002` adds a covering index on `key_sequences(key_sequence, input_type, input_id, n_syls)` → 6 ms→0.04 ms/lookup, <0.4 ms/key. Baked into the db by `rebuild-db` (dbgen runs migrations) AND applied at runtime to existing installs (`Database::open` → `migrate_to_latest`, user_version 1→2). `build_sql_from_csv` only inserts (no table drops), so migrate-then-insert is safe.
- **Rule:** before "optimizing" candidate code, `sqlite3 <db> "EXPLAIN QUERY PLAN <q>"` — you want `SEARCH … USING … INDEX`, not `SCAN`. The runtime db is in-memory (restored from file), so an index seek is the whole win.
- **macOS shell:** `resetWindow()` (`swift/osx/src/candidates/InputController+window.swift`) builds the candidate `NSHostingController` **once** and only repositions it; the view observes `candidateViewModel` (`@Published`). Never rebuild the SwiftUI host per keystroke.

## macOS IME: install, TIS, "no menu" (read before touching `swift/osx` — these cost hours)

- **Changes take effect only via the `.pkg`, not `build-osx`'s copy.** `build-osx` copies the `.app` into `~/Library/Input Methods/` but does NOT quit the running IME or re-register it. **Install the generated `KhiinPJH-<v>.pkg`** — its `preinstall` quits the old IME, `postinstall` `open`s it (TIS re-register). (`build.sh` re-signs ad-hoc because swift/lipo output is unsealed; fine on macOS 26.)
- **"No menu / appears but unusable" = duplicate IME bundle.** Every `build-osx` re-registers its `.build/artifacts/<profile>/KhiinPJH.app`, so two paths claim `app.khiin.inputmethod.khiin` → IMK connection clash. **After build-osx run `lsregister -u .build/artifacts/<profile>/KhiinPJH.app`**, then confirm `lsregister -dump | grep -iE "path:.*KhiinPJH\.app"` shows only the `~/Library/Input Methods/…` path. (Diagnose which build is live: IME log's `resetWindow():<line>` vs current source line.) helper `app.khiin` dupes are harmless — `openSettingApp()` launches by explicit path.
- **The TIS live list is the ONLY authority** for "missing from Input Sources": throwaway Swift `TISCreateInputSourceList(nil, false)` — if `app.khiin.inputmethod.khiin enabled=YES` it's genuinely usable, **so do NOT tell the user to log out.** Do NOT trust `defaults read com.apple.HIToolbox AppleEnabledInputSources` (lagging snapshot on macOS 26.x).
- **Settings apply immediately:** the IME reloads `settings.toml` in `activateServer` (`EngineController.reloadSettings()`), so helper changes (e.g. 自動/自由 input mode) take effect on next focus — not only when the helper quits.
- **Dead ends — don't re-investigate:** ad-hoc signing / no Developer ID still *enables* fine on macOS 26; `TISIntendedLanguage = taioanese` is non-standard but works; Developer ID + notarization matter only for Gatekeeper *distribution*. The "phantom enabled" upgrade case (TIS `IsEnabled` true but hidden) clears ONLY via logout/login — but verify with the live list first.

## Settings app (`khiin_helper`, `app/`) — Tauri **v2** + SvelteKit

- **Frontend (`app/frontend`, Svelte 3 + Tailwind) is SHARED by macOS AND Windows.** macOS UI is gated by `isMac` (`app/frontend/src/lib/platform.ts`, from `is_windows`); **Windows keeps its `{:else}` branch in each page — do not touch it.** macOS nav 一般/輸入/按鍵/關於; grouped cards `SettingsGroup`/`SettingsRow`/`Segmented`, "已套用" `Toast`. Telex 9-key remap is its own `/keys` route (macOS).
- **v2 specifics:** invoke from `@tauri-apps/api/core` (NOT `/tauri`); conf (`app/src-tauri/tauri.conf.json`) is v2 schema; **CLI must be v2** (`Makefile.toml` pins `install-tauri-cli` to `'^2'`; a mismatched CLI fails with `"identifier" is a required property`); `beforeDevCommand` runs in `app/frontend`, so conf uses `npm run dev`. Backend `app/src-tauri/src/main.rs` exposes 4 commands: `load_settings`, `update_settings`, `is_windows`, `app_version`.
- **Build (build-osx does NOT build the helper):** `cd app && cargo tauri build --target universal-apple-darwin --bundles app [--debug]` (`--bundles app` skips the dmg → faster); build-osx then copies `target/universal-apple-darwin/<debug|release>/bundle/macos/khiin_helper.app`. First build needs icons: `cargo tauri icon app/frontend/static/app-icon.png`. **Dev:** `cd app && cargo tauri dev`. **Launch the helper via `NSWorkspace`, never exec its binary** (LSBackgroundOnly IME spawning the WebKit helper as a child hangs).
- **i18n: 3 locales `en` / `oan_Han` / `oan_Latn`** (`fallbackLocale: "en"`) — add every new string to all three. `oan_Latn.json` POJ uses Unicode combining chars → Edit string-match fails on NFC/NFD; anchor on ASCII-only lines. Validate: `node -e "JSON.parse(require('fs').readFileSync('f','utf8'))"`.

## Versions (3 files, keep identical per release — **current 0.3.6**)

`swift/osx/build.sh` (`version=`, free string → pkgbuild + IME Info.plist) · `app/src-tauri/Cargo.toml` · `app/src-tauri/tauri.conf.json` (shown in Settings → About via `app_version = env!("CARGO_PKG_VERSION")` — **never hardcode a version in Svelte**). **No 4th digit** (`0.3.3.1` isn't semver; Cargo/tauri reject it) — use a real patch bump. Asset `Info.plist` / `Makefile.toml` may lag at `0.1.0` (build.sh stamps the real version). The pkg is **unsigned** (`pkgbuild` no `--sign`): local install OK, distribution needs codesign + notarize. The IME menu's top row shows version + build time so builds are distinguishable.

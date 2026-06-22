# CLAUDE.md

Guidance for Claude Code in this repo. **Current version: 0.3.7.**

Khíín = cross-platform Taiwanese (Hō-ló / Tâi-gí) IME. **One Rust engine + thin per-platform shells**; every shell (macOS, iOS, Windows, Android, CLI, settings app) talks to it via one function passing serialized protobuf bytes.

## Working rules (read first)

- **Commit straight to `master`, no feature branches** (user preference). Stage only files you changed; **never `git add -A`** (grabs the 20–37 MB root `*.pkg`). `commit.gpgsign` on → `git commit --no-gpg-sign` (else dies `No pinentry`). End msgs with the `Co-Authored-By` trailer. Push only when asked.
- **Don't edit this CLAUDE.md on your own** — the user maintains it; only when they explicitly ask.
- **cargo/cargo-make are NOT on Claude's Bash PATH** — prefix every cargo cmd: `export PATH="$HOME/.cargo/bin:$PATH"`. Run cargo-make from **repo root** (elsewhere → "Task not found").
- gitignored: `*.pkg`, `resources/khiin.db`, `target/`, `app/build/`, `app/src-tauri/gen/schemas`, `**/.impeccable/`.

## Build & dev

```
cargo make run        # build + run terminal IME (fastest engine exercise)
cargo make test       # engine unit tests
cargo make rebuild-db # clean+regen resources/khiin.db (after *.csv / migration SQL / dbgen edits)
cargo make format     # rustfmt (nightly)
```
Single test: `cargo test --manifest-path=khiin/Cargo.toml <name>`. **Tests/CLI need `target/debug/khiin.db`, which `cargo make test` does NOT build** — fresh checkout: `cargo make build-db && cargo make copy-db`, else `Engine::new`→`None` and every engine test fails. `build-db` is gated on CSV/migration/`database.rs`/dbgen edits (else logs `Skipping Task`; `rebuild-db` forces). dbgen always builds a fresh, fully-migrated db.

### Per-platform (each runs only on its host OS)
- **macOS IME:** `cargo make build-osx` — builds swift-bridge `.a` (**all 5 Apple `rustup` targets must be installed**; always compiles iOS too), the Swift IME, **installs to `~/Library/Input Methods/`**, pkgbuilds `swift/osx/.build/artifacts/<debug|release>/KhiinPJH-<v>.pkg`. `--profile release` (→ `RELEASE_MODE=release`) for release.
- **macOS dev loop:** `build-osx` once → `cargo make watch-osx` (only `swift build`; does **NOT** rebuild the Rust bridge — rerun `build-osx`/`build-swift-bridge` after engine or `swift/bridge` edits). Logs: `~/Library/Caches/KhiinPJH/khiin_im.log`.
- **Windows:** `build-win32`. **Android:** `build-droid`. **iOS:** `xcodegen` → Xcode.

## Architecture

- **Single entry point:** `Engine::send_command_bytes(&[u8]) -> Vec<u8>` (`khiin/src/engine.rs`) — one `match` over `CommandType` → `on_*` handlers. `on_revert`/`on_select_candidate`/`on_list_emojis`/`on_reset_user_data` are still `Err("Not implemented")` = the live backlog.
- **Protobuf** (`protos/src/{command,config}.proto`): `Request` = `KeyEvent`+`AppConfig`; `Response` = `Preedit`+`CandidateList`+`EditState`+committed text. Rust auto-regens via `protos/build.rs`; **Swift does NOT — run `cargo make build-swift-protos`** or fields silently mismatch.
- **Engine internals:** `Engine` = `BufferMgr` (`khiin/src/buffer/buffer_mgr.rs`) + `EngInner{Database,Dictionary,Config}`. Candidate search: segment raw input by word-list prob (`data/segmenter.rs`), look up each segment, rank by uni/bigram. Romaji→syllable→key in `khiin/src/input/`. **3 input modes (Continuous/Classic/Manual) change key semantics throughout `on_send_key` — handle all three.**
- **Data:** `data/data/*.csv` (Tâi Jī Siā) → SQLite `resources/khiin.db` via `khiin/dbgen`; edit CSV → `rebuild-db`. Db also accrues user n-gram data at runtime.
- **Workspace:** `khiin`(engine)+`khiin/dbgen`; `khiin_ji`(`ji/`, stateless lomaji/tone/unicode); `khiin_protos`(`protos/`); `khiin_data`(`data/`). Shells: `cli/`, `swift/{osx,bridge,shared,ios}`, `windows/{ime,service}`, `android/{rust,app}`, `app/`(settings).

## Performance

- **Typing-lag's real cause is the engine DB, not the UI (fixed 0.3.6).** `conversion_lookups` is a VIEW filtering `key_sequences` by `key_sequence`; stale indexes named non-existent columns → full `SCAN` of ~182k rows several times/keystroke (25–80 ms/key). Migration `002` added a covering index `key_sequences(key_sequence, input_type, input_id, n_syls)` (→ <0.4 ms/key) and dropped the stale `input_numeric/telex_covering_index`. **Rule:** before "optimizing" candidate code, `sqlite3 <db> "EXPLAIN QUERY PLAN <q>"` — want `SEARCH … USING INDEX`, not `SCAN`.
- **Migrations are append-only once released** — existing installs only run migrations past their `user_version`, so to fix schema add the next number, never edit a shipped one (in-dev latest is editable). dbgen bakes all migrations in; `Database::open`→`migrate_to_latest` applies them at runtime to existing installs. Verify fast: `sqlite3 fresh.db < migrations/001/up.sql && < 002/up.sql`, check `sqlite_master`.
- **Candidate window host-reuse — KEEP it, never revert.** `ensureWindow()` (`swift/osx/src/candidates/InputController+window.swift`) builds the `NSWindow`+`NSHostingController` **once**, pins leading once; `resetWindow()` only repositions + flips the vertical anchor when the side changes. Content updates reactively via `@Published candidateViewModel`. `resetWindow()` runs at ~14 sites (every key / candidate-move / commit) — **rebuilding the host per keystroke makes typing AND selection slow** (the pre-0.3.6 behavior; a 0.3.7 revert reproduced exactly this regression, since reverted). A "選字選單回穩定做法"-type request is about the selection **method / UI** (interaction, like 0.3.0), **NOT** the window host lifecycle — don't conflate; ask which before touching this file.

## macOS IME: install, TIS, "no menu" (read before touching `swift/osx` — costs hours)

- **Changes take effect only via the `.pkg`, not `build-osx`'s copy.** build-osx copies the `.app` to `~/Library/Input Methods/` but does NOT quit/re-register the running IME. **Install `KhiinPJH-<v>.pkg`** (preinstall quits the old IME, postinstall re-registers via TIS). build.sh re-signs ad-hoc (swift/lipo output unsealed; fine on macOS 26).
- **"No menu / appears but unusable" = duplicate IME bundle.** Every build-osx re-registers its `.build/artifacts/<profile>/KhiinPJH.app`, so multiple paths claim `app.khiin.inputmethod.khiin` → IMK clash. **After build-osx: `lsregister -u` AND `rm -rf` both `.build/artifacts/{debug,release}/KhiinPJH.app`** — `lsregister -u` alone doesn't stick while the bundle exists on disk; the `.pkg` is already written and the install lives in `~/Library/Input Methods`, so the artifacts are disposable. Confirm `lsregister -dump | grep -iE "path:.*KhiinPJH\.app"` shows only the Input Methods path (the nested `khiin_helper.app` there is a different bundle id, harmless).
- **The TIS live list is the ONLY authority** for "missing from Input Sources": throwaway Swift `TISCreateInputSourceList(nil,false)` — if `app.khiin.inputmethod.khiin enabled=YES` it's genuinely usable, **so do NOT tell the user to log out.** Don't trust `defaults read com.apple.HIToolbox AppleEnabledInputSources` (lagging snapshot on macOS 26.x).
- **Settings apply on next focus:** the IME reloads `settings.toml` in `activateServer` (`EngineController.reloadSettings()`), so helper changes take effect when you click back into a text field.
- **Dead ends — don't re-investigate:** ad-hoc signing / no Developer ID still *enables* fine on macOS 26; `TISIntendedLanguage = taioanese` is non-standard but works; Developer ID + notarization matter only for Gatekeeper *distribution*.

## Settings app (`khiin_helper`, `app/`) — Tauri v2 + SvelteKit

- **Frontend (`app/frontend`, Svelte 3 + Tailwind) is SHARED by macOS AND Windows.** macOS UI is gated by `isMac` (`lib/platform.ts`, from `is_windows`); **Windows keeps its `{:else}` branch per page — do not touch it.** macOS nav 一般/輸入/按鍵/關於; cards `SettingsGroup`/`SettingsRow`/`Segmented`, `Toast`. Telex 9-key remap is the `/keys` route (macOS).
- **v2 specifics:** invoke from `@tauri-apps/api/core` (NOT `/tauri`); conf (`app/src-tauri/tauri.conf.json`) is v2 schema; **CLI must be v2** (Makefile pins `install-tauri-cli` `'^2'`; mismatch fails `"identifier" is a required property`). Backend `app/src-tauri/src/main.rs` = 4 commands: `load_settings`/`update_settings`/`is_windows`/`app_version`.
- **Build (build-osx does NOT build the helper — build it first):** `cd app && cargo tauri build --target universal-apple-darwin --bundles app [--debug]` (`--bundles app` skips the dmg); build-osx then copies `target/universal-apple-darwin/<debug|release>/bundle/macos/khiin_helper.app`. First build needs icons: `cargo tauri icon app/frontend/static/app-icon.png`. **Launch the helper via `NSWorkspace`, never exec its binary** (the LSBackgroundOnly IME spawning the WebKit helper as a child hangs).
- **i18n: 3 locales `en` / `oan_Han` / `oan_Latn`** (`fallbackLocale: en`) — add every new string to all three. `oan_Latn` POJ uses combining chars → Edit string-match fails on NFC/NFD; anchor on ASCII-only lines. Validate: `node -e "JSON.parse(require('fs').readFileSync('f','utf8'))"`.
- **Switch-mode shortcut is user-recordable (0.3.7), for keyboards without a `~` key.** `ShortcutRecorder.svelte` records a W3C `event.code` → `input_mode_shortcut` in settings.toml → `swift/bridge/lib.rs` maps it onto `AppConfig.input_mode_shortcut` → Swift `ModeShortcut.parse` (`swift/osx/src/keys/ModeShortcut.swift`) → `InputController+handler`. Values: `default` (⌥+`), `shift` (lone Shift, Windows-compat), a lone-modifier code (e.g. `MetaRight`), or `<Mod>+<Code>` combo. `.flagsChanged` is in `recognizedEvents` so a lone-modifier tap can be detected. Windows page still offers only the default/shift dropdown.

## Versions & release-prep (3 files identical per release — **current 0.3.7**)

`swift/osx/build.sh` (`version=`, → pkgbuild + IME Info.plist) · `app/src-tauri/Cargo.toml` · `app/src-tauri/tauri.conf.json` (Settings→About reads `app_version = env!("CARGO_PKG_VERSION")` — **never hardcode a version in Svelte**). **No 4th digit** (`0.3.3.1` isn't semver; Cargo/tauri reject it). The pkg is **unsigned** (local install OK; distribution needs codesign + notarize). The IME menu's top row shows version + build time, so builds are distinguishable even at the same version.
- **After any version bump, prepare the debug on-device test artifacts** (user standing rule): build the helper `--debug`, then `cargo make build-osx` (installs + pkgbuilds the debug `.pkg`), then dedup (`lsregister -u` + `rm` the artifact bundles). Tell the user the `.pkg` path to install.

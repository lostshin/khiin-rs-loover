# Khíín Taiwanese IME

![CI Build & Test](https://github.com/lostshin/khiin-rs-loover/actions/workflows/ci.yml/badge.svg?branch=master)

**Languages:** English · [台語漢字 (Tâi-Hàn)](README-TAI-HAN.md) · [台羅 (Tâi-lô)](README-TAI-LO.md) · [台灣華語 (Mandarin)](README.zh-TW.md)

**Khíín** is a cross-platform input method for typing Taiwanese. We aim to
support all major platforms, including Windows, Android, macOS, iOS, Linux, and
the web. Our goal is simple: to provide an excellent Taiwanese typing
experience.

If you are interested in contributing, please open an issue!

- [Khíín Taiwanese IME](#khíín-taiwanese-ime)
  - [About this fork](#about-this-fork)
  - [Installation](#installation)
  - [Usage](#usage)
  - [Help](#help)
- [Development](#development)
  - [Database](#database)
  - [Khiin (Engine)](#khiin-engine)
  - [App (Settings \& Guide)](#app-settings--guide)
  - [Protobuf](#protobuf)
  - [Windows App](#windows-app)
  - [Android App](#android-app)
  - [iOS \& macOS Apps](#ios--macos-apps)
  - [Development CLI App](#development-cli-app)
    - [Quickstart](#quickstart)


## About this fork

This repository is a fork of
[`OMAMA-Taioan/khiin-rs`](https://github.com/OMAMA-Taioan/khiin-rs), focused on
bringing the IME up on **macOS** and modernizing the settings app. It is
currently **22 commits ahead of upstream**, with no upstream changes pending
(60 files, +3216 / −449 lines). The core input engine is largely untouched — the
work concentrates on the per-platform shells.

| Area | What this fork adds |
| --- | --- |
| **macOS IME** (`swift/`) | Fixes IME registration, helper launch, version display, and the candidate-window lifecycle; adds a user-recordable mode-switch shortcut. The IME installs and is usable on macOS. |
| **Settings app** (`app/`) | Migrates the Tauri backend from v1 to v2; adds a native macOS input-settings UI (segmented controls, a key-remap page). |
| **Engine** (`khiin/`) | Adds a covering index on `key_sequences` to fix per-keystroke typing lag, plus reliable, append-only database migrations. |
| **Docs** | Refreshed `CLAUDE.md` / `AGENTS.md` contributor guidance. |

The version has advanced to **0.3.7**.

## Installation

TODO

## Usage

TODO

## Help

TODO

---

# Development

```
khiin-rs/
├── android/
│   ├── app         # Jetpack Compose Android app
│   └── rust        # JNI glue library for khiin
├── app/            # Settings & help app
│   ├── frontend    # Svelte frontend
│   ├── settings    # Settings manager (Khiin.toml)
│   └── src-tauri   # Tauri backend
├── cli/            # Terminal application (for developers)
├── data/           # CSV databases (Provided by Tâi Jī Siā)
├── ji/             # Taiwanese script handling library
├── khiin/          # Cross-platform engine library
│   └── dbgen/      # CLI tool to generate the DB
├── protos/         # Protobuf definitions
├── resources/
│   └── khiin.db    # Generated db file
├── swift/          # iOS and macOS applications
├── windows/
│   ├── ime/        # TSF library
│   ├── res/        # Windows specific resources
│   └── service/    # Engine manager service
└── Makefile.toml   # Cargo build tasks
```

All development tasks are defined in [`Makefile.toml`](Makefile.toml), which
requires `cargo-make`:

```bash
cargo install --force cargo-make

# Show all available build tasks
cargo make --list-all-steps
```

## Database

```
khiin-rs/
├── data/
│   ├── data/
│   │   ├── conversions_all.csv
│   │   └── frequency.csv
│   └── Cargo.toml
```

The engine library embeds the CSVs and produces the database at first run. For
inspection of the database, use the CLI tool included in the engine crate. See
[data/README.md](data/README.md) for details.

- `frequency.csv` contains the romanized wordlist with a rough frequency count
  for each item based on the available corpus.
- `conversions_all.csv` contains the possible outputs (both romanized or hanji)
  for a given word, plus additional information.

The database generator converts the romanized wordlist into ASCII key sequences,
including with and without tones, and builds tables for numeric and telex input
sequences, as well as a table listing the probability of each word based on the
frequency counts.

The database is continually updated with user data during use, to improve
candidate prediction based on a simple N-gram model that currently uses 1-gram
and 2-gram frequencies. In the future this may be extended to other prediction
algorithms for better results.

In addition to `khiin.db`, users may provide an additional custom dictionary
file, which is simply a text file listing rows of space-delimited `input output`
options to display as candidates. (Everything after the first space is taken as
the output.) These candidates are displayed in addition to the default database.

At present, data is not shared at all, and is strictly used within the
application itself. In future we would like to add an option to sync user's data
across devices, and an option to allow users to share their (anonymized) data
with us for improving our corpus.

## Khiin (Engine)

The engine maintains a stateful buffer during each input session with a client
application. The buffer can contain various types of items depending on whether
the input sequence has matches in the conversion database, the user's own custom
database, or full/half-width punctuation, etc.

Candidate search is a two-step process. We first use the word list probabilities
to segment the user's input sequence (if they don't segment it themselves while
typing), and then search for each segment in the conversion table, using the
unigram and bigram records to sort the resulting options.

## App (Settings & Guide)

The app is a [Tauri](https://tauri.app/) & [Svelte](https://svelte.dev/)
cross-platform app built in Rust & TypeScript. The goal here is to provide a
consistent UI for managing settings on all desktop platforms, and to provide
instructions for using the IME or other useful materials.

See the [README](app/README.md) for more details.

## Protobuf

The engine and client applications communicate using protocol buffers. The
engine exposes a single function endpoint:

```rust
send_command_bytes(bytes: &[u8]) -> Vec<u8>
```

The input/output bytes are both a serialized `khiin_protos::Command` protocol
buffer, which contains both a `Request` and a `Response` message. Clients should
tag each `Request` with an id, so that the client can associate the correct
`Response`.

## Windows App

The Windows IME is mostly complete, although it is still missing a few key
features for release. The app includes the IME itself, as well as a Settings
application that allows the user to configure the IME, and a basic WiX installer.

See the [windows/README.md](windows/README.md) for more details.

## Android App

The Android IME is currently in progress / unstable. It is a modern Jetpack
Compose app written in Kotlin. The `android/rust` folder contains a small
wrapper around `khiin` that communicates with the Android app via JNI.

See the [android/README.md](android/README.md) for more details.

## iOS & macOS Apps

The **macOS IME is functional** in this fork: it installs as a system input
method, shows a candidate window for selection, ships a native settings app, and
supports a user-recordable mode-switch shortcut. It is usable for daily typing
but still pre-release — a few engine commands (revert, emoji list, user-data
reset) are not yet wired up.

The **iOS app** is still in progress / unstable. Basic setup between the Khiin
engine and the app is complete, so the remaining work is mainly to build out the
UI and hook up the engine wiring.

See the [swift/README.md](swift/README.md) for more details.

## Development CLI App

This is a very basic terminal application intended for developers or database
maintainers to quickly work on the engine and preview changes without needing to
load up a full application. The terminal application has been tested to work on
any platform, including Windows.

This tool demonstrates all of the available features of the engine, which can be
used in the various client applications. Follow the quickstart guide below for
setting up the CLI app independently of any other client applications.

### Quickstart

- All commands should be run from the root `khiin-rs` directory

Install rust:

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Reload your terminal to source the new files. Then install `cargo-make`:

```
cargo install --force cargo-make
```

Clone this repo and build it:

```
git clone https://github.com/lostshin/khiin-rs-loover.git
cd khiin-rs-loover
cargo make build-cli
```

Run the terminal application:

```
./target/debug/khiin_cli
```

To rebuild the database after an update, run:

```
cargo make rebuild-db
```

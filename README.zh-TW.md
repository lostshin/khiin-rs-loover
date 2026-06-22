# Khíín 台語輸入法

![CI Build & Test](https://github.com/lostshin/khiin-rs-loover/actions/workflows/ci.yml/badge.svg?branch=master)

**語言版本：** [English](README.md) · [台語漢字 (Tâi-Hàn)](README-TAI-HAN.md) · [台羅 (Tâi-lô)](README-TAI-LO.md) · 台灣華語

**Khíín** 是一套跨平台的台語輸入法。我們希望支援所有主要平台，包括 Windows、
Android、macOS、iOS、Linux 與網頁。目標很單純：提供一個出色的台語打字體驗。

如果你有興趣參與貢獻，歡迎開一個 issue！

- [Khíín 台語輸入法](#khíín-台語輸入法)
  - [關於這個 fork](#關於這個-fork)
  - [安裝](#安裝)
  - [使用](#使用)
  - [說明](#說明)
- [開發](#開發)
  - [資料庫](#資料庫)
  - [Khiin 引擎](#khiin-引擎)
  - [設定與說明 App](#設定與說明-app)
  - [Protobuf](#protobuf)
  - [Windows 程式](#windows-程式)
  - [Android 程式](#android-程式)
  - [iOS 與 macOS 程式](#ios-與-macos-程式)
  - [開發用 CLI 程式](#開發用-cli-程式)
    - [快速上手](#快速上手)


## 關於這個 fork

本儲存庫是 [`OMAMA-Taioan/khiin-rs`](https://github.com/OMAMA-Taioan/khiin-rs)
的 fork，重點放在把這套輸入法在 **macOS** 上跑起來，並把設定 app 現代化。目前
**領先上游 22 個 commit**，且沒有任何上游更新待合併（60 個檔案、+3216 / −449
行）。輸入引擎核心幾乎沒有改動——主要的功夫集中在各平台的殼層。

| 區域 | 本 fork 新增的東西 |
| --- | --- |
| **macOS 輸入法**（`swift/`）| 修復 IME 註冊、helper 啟動、版本顯示，以及選字視窗的生命週期；新增可由使用者自訂錄製的切換模式快捷鍵。輸入法已可安裝，並在 macOS 上可用。 |
| **設定 app**（`app/`）| 把 Tauri 後端從 v1 遷移到 v2；新增原生的 macOS 輸入設定介面（segmented 控制項、按鍵重新對應頁面）。 |
| **引擎**（`khiin/`）| 在 `key_sequences` 上加一個 covering index，修掉每次按鍵的打字卡頓；並讓資料庫 migration 變得可靠、且只增不改。 |
| **文件** | 更新 `CLAUDE.md` / `AGENTS.md` 的貢獻者指引。 |

版本已推進到 **0.3.7**。

## 安裝

TODO

## 使用

TODO

## 說明

TODO

---

# 開發

```
khiin-rs/
├── android/
│   ├── app         # Jetpack Compose Android 程式
│   └── rust        # khiin 的 JNI 膠合函式庫
├── app/            # 設定與說明程式
│   ├── frontend    # Svelte 前端
│   ├── settings    # 設定管理器（Khiin.toml）
│   └── src-tauri   # Tauri 後端
├── cli/            # 終端機程式（給開發者）
├── data/           # CSV 資料庫（由 Tâi Jī Siā 提供）
├── ji/             # 台語文字處理函式庫
├── khiin/          # 跨平台引擎函式庫
│   └── dbgen/      # 產生資料庫的 CLI 工具
├── protos/         # Protobuf 定義
├── resources/
│   └── khiin.db    # 產生出來的資料庫檔
├── swift/          # iOS 與 macOS 程式
├── windows/
│   ├── ime/        # TSF 函式庫
│   ├── res/        # Windows 專屬資源
│   └── service/    # 引擎管理服務
└── Makefile.toml   # Cargo 建置任務
```

所有開發任務都定義在 [`Makefile.toml`](Makefile.toml) 裡，需要 `cargo-make`：

```bash
cargo install --force cargo-make

# 列出所有可用的建置任務
cargo make --list-all-steps
```

## 資料庫

```
khiin-rs/
├── data/
│   ├── data/
│   │   ├── conversions_all.csv
│   │   └── frequency.csv
│   └── Cargo.toml
```

引擎函式庫會內嵌這些 CSV，並在第一次執行時產生資料庫。若要檢視資料庫，請使用引擎
crate 內附的 CLI 工具。詳見 [data/README.md](data/README.md)。

- `frequency.csv` 是羅馬字詞表，依現有語料庫為每個項目附上一個粗略的頻率計數。
- `conversions_all.csv` 是某個詞所有可能的輸出（羅馬字或漢字），外加其他資訊。

資料庫產生器會把羅馬字詞表轉換成 ASCII 按鍵序列（包含有聲調與無聲調的版本），並
建立 numeric 與 telex 輸入序列的表格，以及一張依頻率計數列出每個詞機率的表格。

資料庫會在使用過程中持續以使用者資料更新，透過一個簡單的 N-gram 模型來改善候選字
預測，目前使用 1-gram 與 2-gram 的頻率。未來可能擴充到其他預測演算法以得到更好的
結果。

除了 `khiin.db`，使用者還可以提供一個額外的自訂字典檔，那只是一個純文字檔，逐行
列出以空白分隔的 `input output` 選項，作為候選字顯示。（第一個空白之後的全部內容
都視為 output。）這些候選字會與預設資料庫一起顯示。

目前資料完全不會分享，僅嚴格用於程式本身。未來我們希望加入跨裝置同步使用者資料的
選項，以及讓使用者選擇是否把（匿名化的）資料分享給我們，以改善我們的語料庫。

## Khiin 引擎

引擎在每次與客戶端程式的輸入工作階段中，會維護一個有狀態的緩衝區。緩衝區可以包含
各種型別的項目，取決於輸入序列在轉換資料庫、使用者自己的自訂資料庫、或全形／半形
標點符號等是否有對應的結果。

候選字搜尋是兩步驟的過程。我們先用詞表機率把使用者的輸入序列分段（如果使用者打字
時自己沒有分段的話），再到轉換表裡搜尋每個分段，用 unigram 與 bigram 紀錄來對結果
排序。

## 設定與說明 App

這個 app 是用 [Tauri](https://tauri.app/) 與 [Svelte](https://svelte.dev/) 以
Rust 與 TypeScript 打造的跨平台程式。目標是在所有桌面平台上提供一致的設定管理
UI，並提供使用輸入法的說明或其他有用的素材。

更多細節請見 [README](app/README.md)。

## Protobuf

引擎與客戶端程式之間使用 protocol buffer 溝通。引擎只對外暴露單一一個函式端點：

```rust
send_command_bytes(bytes: &[u8]) -> Vec<u8>
```

輸入／輸出的 bytes 都是一個序列化的 `khiin_protos::Command` protocol buffer，
裡面同時包含一個 `Request` 與一個 `Response` 訊息。客戶端應該為每個 `Request`
標上一個 id，這樣才能對應到正確的 `Response`。

## Windows 程式

Windows 輸入法大致完成，不過離正式發布還缺幾個關鍵功能。這個程式包含輸入法本身、
一個讓使用者設定輸入法的設定程式，以及一個基本的 WiX 安裝程式。

更多細節請見 [windows/README.md](windows/README.md)。

## Android 程式

Android 輸入法目前仍在開發中／不穩定。它是一個用 Kotlin 寫的現代 Jetpack Compose
程式。`android/rust` 資料夾裡有一個包住 `khiin` 的小型 wrapper，透過 JNI 與
Android 程式溝通。

更多細節請見 [android/README.md](android/README.md)。

## iOS 與 macOS 程式

在這個 fork 裡，**macOS 輸入法已可使用**：它會以系統輸入法的身分安裝、顯示選字
視窗供選字、附帶一個原生設定 app，並支援可由使用者自訂錄製的切換模式快捷鍵。它已
可用於日常打字，但仍屬發布前狀態——少數引擎指令（復原、emoji 清單、重設使用者資料）
還沒接上。

**iOS 程式**仍在開發中／不穩定。Khiin 引擎與程式之間的基本串接已完成，剩下的工作
主要是把 UI 做出來、並把引擎的接線接好。

更多細節請見 [swift/README.md](swift/README.md)。

## 開發用 CLI 程式

這是一個非常基本的終端機程式，給開發者或資料庫維護者用來快速處理引擎、預覽改動，
而不需要載入一整個完整的程式。這個終端機程式已測試過可在任何平台上運作，包括
Windows。

這個工具展示了引擎所有可用的功能，這些功能可以用在各種客戶端程式上。依照下面的快速
上手指南，就能獨立於其他客戶端程式設定好這個 CLI 程式。

### 快速上手

- 所有指令都應該在根目錄 `khiin-rs` 下執行

安裝 rust：

```
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

重新載入你的終端機以載入新的檔案。接著安裝 `cargo-make`：

```
cargo install --force cargo-make
```

clone 這個 repo 並建置：

```
git clone https://github.com/lostshin/khiin-rs-loover.git
cd khiin-rs-loover
cargo make build-cli
```

執行終端機程式：

```
./target/debug/khiin_cli
```

更新之後若要重建資料庫，執行：

```
cargo make rebuild-db
```

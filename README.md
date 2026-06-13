# Audiopig

A focused local-file audiobook player for iOS — built with SwiftUI, SwiftData, and AVFoundation.

![iOS 26.5+](https://img.shields.io/badge/iOS-26.5%2B-black?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-%E2%9C%93-blue?style=flat-square)
![SwiftData](https://img.shields.io/badge/SwiftData-%E2%9C%93-purple?style=flat-square)

<!-- screenshots -->

---

## Features

- **Local file import** — import `.mp3` and `.m4b` files directly from the Files app, or pick an entire folder
- **Multi-chapter virtual timeline** — merge multiple audio files into a single continuous book with per-chapter seeking
- **Full playback engine** — speed control (0.5–3.0×), configurable skip intervals, dual scrubber mode (entire book or current chapter)
- **Bookmarks** — save named timestamps, jump back at any time, swipe to delete
- **Sleep timer** — off, N minutes, or end of current chapter
- **Background audio** — continues playing when the screen is off or the app is backgrounded
- **Lock screen controls** — play/pause, skip forward/back, and scrubbing via `MPRemoteCommandCenter`
- **Persistent playback position** — saved every 5 seconds during playback and immediately on backgrounding
- **Library management** — search, multi-select, bulk delete, cover art extracted from file metadata
- **Appearance** — system, light, or dark mode

---

## Architecture

Audiopig follows strict MVVM. Views contain zero business logic and have no direct access to AVFoundation.

```
Views (SwiftUI)
  └─▶ ViewModels (@Observable)
        └─▶ Services (AudioEngine, LibraryManager, AppSettings)
              └─▶ Persistence (SwiftData · UserDefaults · File System)
```

Key constraints:
- All playback calls go through `AudioEngineProtocol` — the concrete `AudioEngine` is never imported by a view or view model directly
- `DependencyContainer` constructs and wires all services at launch (`AudiopigApp.swift`)
- Visual tokens (colors, typography, spacing, shadows) live exclusively in `DesignSystem.swift`; ad-hoc styling in views is a regression

---

## Project Structure

```
Audiopig/
└── Audiopig/
    ├── Models/                 SwiftData @Model types: Audiobook, Chapter, Bookmark
    ├── ViewModels/             LibraryViewModel, PlayerViewModel (@Observable)
    ├── Views/                  SwiftUI screens: MainTabView, LibraryView, PlayerView,
    │   │                       SettingsView, ChaptersListView, BookmarksListView
    │   └── Components/         MiniPlayerView, AudiobookRowView, CircularProgressView
    ├── Services/               AudioEngine, LibraryManager, AudiobookMetadataExtractor,
    │                           AppSettings, CoverArtCache
    ├── Protocols/              AudioEngineProtocol, LibraryManagerProtocol
    ├── DependencyInjection/    DependencyContainer, AudiopigModelContainer
    ├── Design/                 DesignSystem, GlassModifiers, ButtonStyles, ViewExtensions
    ├── Fonts/                  Clash Display (.otf) — bundled, registered in Info.plist
    ├── Support/                PlaybackState, LibraryManagerError, AudiobookProgressFormatter
    └── Assets.xcassets/        App icon, accent color
```

---

## Requirements

- **Xcode 26 or later**
- **iOS 26.5+** deployment target (simulator or device)
- **No third-party dependencies** — pure Apple frameworks only; Clash Display font is bundled in `Fonts/`

---

## Build

1. Clone the repo
2. Open `Audiopig/Audiopig.xcodeproj` in Xcode
3. Select a simulator or device running iOS 26.5+
4. `Cmd+R`

---

## Known Gaps

| Area | Status |
|---|---|
| Automated tests | No test target exists yet |
| Sleep timer persistence | Timer state (option + countdown) is lost on app kill |
| Per-book playback speed | Global default from Settings applies on load; not saved per book |
| Format support | Only `.mp3` and `.m4b`; no `.aax`, `.opus`, etc. |

---

## Phase History

| Phase | Milestone |
|---|---|
| 1–8 | Core import pipeline, AVFoundation playback engine, UI scaffolding, design system, bookmarks, settings |
| 9 | Stable audio engine, mini-player, multi-chapter virtual timeline |
| 10 | Folder import, merge file cleanup, dead code removal, README |

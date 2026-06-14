# Audiopig

A focused local-file audiobook player for iOS — built with SwiftUI, SwiftData, and AVFoundation.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-%E2%9C%93-blue?style=flat-square)
![SwiftData](https://img.shields.io/badge/SwiftData-%E2%9C%93-purple?style=flat-square)

<!-- screenshots -->

---

## Features

- **Local file import** — import `.mp3` and `.m4b` files from the Files app, or pick an entire folder
- **Folders** — group audiobooks into folders with optional custom cover art
- **Multi-chapter virtual timeline** — merge multiple audio files into one continuous book with per-chapter seeking
- **Full playback engine** — speed control (0.5–3.0×), configurable skip intervals, dual scrubber mode (entire book or current chapter)
- **Bookmarks** — save named timestamps, edit, jump, long-press browser, swipe to delete, export as table
- **Sleep timer** — off, N minutes, or end of current chapter; persists across app restarts
- **Lull detection** — find paragraph/chapter break points via silence analysis
- **Background audio** — continues playing when the screen is off or the app is backgrounded
- **Lock screen controls** — play/pause, skip forward/back, and scrubbing via `MPRemoteCommandCenter`
- **Persistent playback position** — saved every 5 seconds during playback and on backgrounding
- **Library management** — search, multi-select, bulk delete, merge books, edit title/author/cover art
- **Stats** — total listening time and finished-book count; unlockable app icons at listening milestones
- **Finish celebrations** — confetti and optional delete confirmation when marking a book finished
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
    ├── Models/                 SwiftData @Model types: Audiobook, Chapter, Bookmark, Folder, FinishedRecord
    ├── ViewModels/             LibraryViewModel, PlayerViewModel, StatsViewModel, Edit*ViewModels
    ├── Views/                  MainTabView, LibraryView, PlayerView, SettingsView, StatsView, Edit*Views
    │   └── Components/         MiniPlayerView, ArtworkPickerSection, celebration overlays, row views
    ├── Services/               AudioEngine, LibraryManager, LullDetector, AppSettings, AppIconManager
    ├── Protocols/              AudioEngineProtocol, LibraryManagerProtocol
    ├── DependencyInjection/    DependencyContainer, AudiopigModelContainer
    ├── Design/                 DesignSystem, GlassModifiers, ButtonStyles, ViewExtensions
    ├── Support/                PlaybackState, errors, formatters
    ├── docs/app-store/         QA checklist, listing copy, privacy policy, submission guide
    └── Assets.xcassets/        App icon (+ unlockable tier variants), accent color
```

---

## Requirements

- **Xcode 16 or later** (project created with Xcode 26)
- **iOS 17.0+** deployment target (simulator or device)
- **No third-party dependencies** — pure Apple frameworks only

---

## Build

1. Clone the repo
2. Open `Audiopig/Audiopig.xcodeproj` in Xcode
3. Select a simulator or device running iOS 17+
4. `Cmd+R`

---

## App Store Submission

See `docs/app-store/` for:

- `qa-checklist.md` — manual device QA before submit
- `listing.md` — description, subtitle, keywords, promotional text
- `privacy-policy.html` — host this and paste the URL into App Store Connect
- `submission-guide.md` — archive, upload, and Connect checklist

---

## Known Gaps

| Area | Status |
|---|---|
| Automated tests | No test target exists yet |
| Per-book playback speed | Global default from Settings applies on load; not saved per book |
| Format support | Only `.mp3` and `.m4b`; no `.aax`, `.opus`, etc. |

---

## Phase History

| Phase | Milestone |
|---|---|
| 1–8 | Core import pipeline, AVFoundation playback engine, UI scaffolding, design system, bookmarks, settings |
| 9 | Stable audio engine, mini-player, multi-chapter virtual timeline |
| 10 | Folder import, merge file cleanup, dead code removal, README |
| 11 | Stats tab, lull detection, unlockable icons, bookmarks export, edit details, App Store prep |

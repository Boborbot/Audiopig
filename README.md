# AudioPig

A focused local-file audiobook player for iOS — built with SwiftUI, SwiftData, and AVFoundation.

![iOS 17+](https://img.shields.io/badge/iOS-17%2B-black?style=flat-square)
![Swift](https://img.shields.io/badge/Swift-5-F05138?style=flat-square&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-%E2%9C%93-blue?style=flat-square)
![SwiftData](https://img.shields.io/badge/SwiftData-%E2%9C%93-purple?style=flat-square)
![watchOS 10+](https://img.shields.io/badge/watchOS-10%2B-black?style=flat-square)

<!-- screenshots -->

---

## Features

- **Local file import** — import `.mp3` and `.m4b` files from the Files app (toolbar + button)
- **Folders** — group audiobooks into folders with optional custom cover art
- **Multi-chapter virtual timeline** — merge multiple audio files into one continuous book with per-chapter seeking
- **Full playback engine** — speed control (0.5–3.0×), configurable skip intervals, dual scrubber mode (entire book or current chapter)
- **Bookmarks** — save named timestamps, edit, jump, long-press browser, swipe to delete, export as table
- **Sleep timer** — off, N minutes, or end of current chapter; persists across app restarts
- **Smart Rewind** — Look Far and Look Near scan silence in a window before the playhead to jump back to a natural break; dual-thumb range slider to set the window in settings or via long press (AudioPig Plus; 7-day free trial)
- **Speech EQ & Voice Boost** — EQ presets tuned for narration clarity (Plus); free Voice Boost levels lift quiet passages (Settings and player sheet; per-book or universal defaults)
- **Live subtitles** — on-device transcription near the playhead or for the whole book; search, export, bookmark from a line (AudioPig Plus; requires iOS 26+)
- **Chapter editing** — rename chapters and adjust start times / order in the chapter list
- **Background audio** — continues playing when the screen is off or the app is backgrounded
- **Lock screen controls** — play/pause, skip forward/back, and scrubbing via `MPRemoteCommandCenter`
- **Persistent playback position** — saved every 5 seconds during playback and on backgrounding
- **Library management** — search, multi-select, bulk delete, merge books, edit title/author/cover art
- **Stats** — total listening time and finished-book count; unlockable app icons at listening milestones
- **App icon gallery** — browse and apply hour-tier and secret achievement alternate icons from the Stats tab
- **Finish celebrations** — confetti and optional delete confirmation when marking a book finished
- **Appearance** — system, light, or dark mode; optional portrait orientation lock
- **Landscape player** — when orientation lock is off, the full player splits into artwork+title and controls columns (cover art on the notch side); no scrolling required
- **AudioPig Plus** — monthly subscription unlocks Smart Rewind, Speech EQ, and on-device subtitles; optional "Feed a Student" consumable tips ($2.99 / $6.99 / $14.99) in Settings
- **Apple Watch companion** (`AudiopigWatch`) — remote iPhone playback (recent books, controls, chapters, artwork skip gestures). On-Watch local library transfer is archived until a future release (`WatchFeatures.localPlaybackEnabled`).
- **Home screen widgets** (`AudiopigWidget`) — listening stats, artwork, recent books, hour-club progress, and a lock screen **Continue Listening** circular widget (progress ring + pig glyph; tap resumes last book and opens the player)
- **Lock screen control** (iOS 18+) — optional bottom-corner control to resume the last audiobook (`ContinueListeningControl`)
- **Volume control** — hardware volume integration through `SystemVolumeController`

---

## Architecture

AudioPig follows strict MVVM. Views contain zero business logic and have no direct access to AVFoundation.

```
Views (SwiftUI)
  └─▶ ViewModels (@Observable)
        └─▶ Services (AudioEngine, LibraryManager, AppSettings, WatchConnectivity)
              └─▶ Persistence (SwiftData · UserDefaults · File System · App Group)
```

Key constraints:
- All playback calls go through `AudioEngineProtocol` — the concrete `AudioEngine` is never imported by a view or view model directly
- `DependencyContainer` constructs and wires all services at launch (`AudiopigApp.swift`)
- `AudiopigShared` holds cross-target types (Watch connectivity payloads, widget snapshots, subtitle math, Smart Rewind policy, `ChapterProgressCalculator`)
- Visual tokens (colors, typography, spacing, shadows) live exclusively in `DesignSystem.swift`; ad-hoc styling in views is a regression

---

## Project Structure

```
Audiopig/
├── Audiopig/                   Main iOS app target
│   ├── Models/                 SwiftData @Model types: Audiobook, Chapter, Bookmark, SubtitleCue, Folder, FinishedRecord
│   ├── ViewModels/             LibraryViewModel, PlayerViewModel, StatsViewModel, Edit*ViewModels
│   ├── Views/                  MainTabView, LibraryView, PlayerView, SettingsView, StatsView, Edit*Views
│   │   └── Components/         MiniPlayerView, SubtitlesPanel, SmartRewindWindowRangeSlider, AudioEnhancementControls, celebration overlays, row views
│   ├── Intents/                App Shortcuts (`PlayLastAudiobookIntent`)
│   ├── Services/               AudioEngine, AudioEQTapProcessor, LibraryManager, LullDetector, SubtitleStore, SubtitleGenerationOrchestrator, WatchConnectivity, StoreKit, WidgetSnapshotWriter
│   ├── Protocols/              AudioEngineProtocol, LibraryManagerProtocol, SubtitleStoreProtocol, MonetizationServiceProtocol, WatchTransferServiceProtocol
│   ├── DependencyInjection/    DependencyContainer, AudiopigModelContainer
│   ├── Design/                 DesignSystem, GlassModifiers, ButtonStyles, ViewExtensions
│   ├── Support/                PlaybackState, errors, formatters
│   ├── docs/app-store/         QA checklist, listing copy, privacy policy, submission guide
│   └── Assets.xcassets/        App icon (+ unlockable tier variants), gallery thumbnails
├── AudiopigShared/             Shared Swift sources compiled into app, Watch, and Widget targets
├── AudiopigWatch/              watchOS companion (remote playback; local transfer archived)
├── AudiopigWidget/             WidgetKit extension (stats, artwork, recent books, Continue Listening widget + iOS 18 control)
└── AudiopigTests/              Unit tests (chapter progress, subtitles, Smart Rewind, achievements, monetization, widgets)
```

---

## Requirements

- **Xcode 16 or later** (project created with Xcode 26)
- **iOS 17.0+** deployment target (simulator or device)
- **watchOS 10.0+** for the Watch companion
- **No third-party dependencies** — pure Apple frameworks only

---

## Build

1. Clone the repo
2. Open `Audiopig/Audiopig.xcodeproj` in Xcode
3. Select a simulator or device running iOS 17+
4. `Cmd+R`

### Running tests

Select the **Audiopig** scheme and press `Cmd+U`, or from the command line:

```bash
xcodebuild test -project Audiopig.xcodeproj -scheme Audiopig \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

## App Store Submission

See `docs/app-store/` for:

- `qa-checklist.md` — manual device QA before submit
- `listing.md` — description, subtitle, keywords, promotional text
- `privacy-policy.html` — canonical copy in `docs/app-store/`; public URL: https://audiopig.github.io/privacy-policy.html
- `terms.html` — Terms of Use (EULA); public URL: https://audiopig.github.io/terms.html
- `hosting-setup.md` — publish `support-site/` to the `AudioPig` GitHub org
- `submission-guide.md` — archive, upload, and Connect checklist

---

## Known Gaps

| Area | Status |
|---|---|
| Automated tests | `AudiopigTests` covers pure logic (widgets, subtitles, Smart Rewind, Speech EQ, achievements); no UI or AVFoundation integration tests yet |
| Live subtitles | Requires iOS 26+ and on-device Apple speech models; graceful unavailable message on older OS |
| Per-book playback speed | Global default from Settings applies on load; not saved per book |
| Format support | Only `.mp3` and `.m4b`; no `.aax`, `.opus`, etc. |
| Watch local transfer | Archived (`WatchFeatures.localPlaybackEnabled`); code retained for a future release |
| Bulk folder import + library backup/restore | Archived in `docs/archive/library-migration/` (not compiled); single-file import only |

---

## Phase History

| Phase | Milestone |
|---|---|
| 1–8 | Core import pipeline, AVFoundation playback engine, UI scaffolding, design system, bookmarks, settings |
| 9 | Stable audio engine, mini-player, multi-chapter virtual timeline |
| 10 | Folder import, merge file cleanup, dead code removal, README |
| 11 | Stats tab, lull detection, unlockable icons, bookmarks export, edit details, App Store prep |
| 12 | Watch companion (remote playback), widgets, AudiopigShared, StoreKit monetization, icon gallery, orientation lock, unit tests |
| 13 | App Store v1.0 stabilization, legal URLs on GitHub Pages, iPad full-screen player layout |
| 14 | v1.1 — Smart Rewind, on-device subtitles, chapter editing, 2000h/2500h icons, Sher Pig and Pig Sawyer secret icons |
| 15 | v1.1.1 — Speech EQ & Voice Boost, Smart Rewind range slider, subtitle follow-scroll polish |

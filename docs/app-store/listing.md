# AudioPig — App Store Connect Listing Copy

Paste these fields into App Store Connect. Adjust tone if needed; all claims match current app behavior.

---

## App Name

```
AudioPig
```

---

## Subtitle (30 characters max)

```
Local audiobooks, beautifully
```

(29 characters)

**Alternates:**

- `Your files. Your library.` (26)
- `Play local audiobooks` (21)

---

## Promotional Text (170 characters max, editable without new version)

```
v1.1.2: Stronger Voice Boost levels, EQ remembers your preset when toggled back on, and playback polish. Core player free — try Plus free for 7 days.
```

(149 characters)

**v1.1.1 alternate:**

```
v1.1.1: Speech EQ for clearer narration, Smart Rewind range slider, and smoother subtitle scrolling. Core player free — try Plus free for 7 days.
```

(147 characters)

**v1.1 alternate:**

```
v1.1: Smart Rewind, on-device subtitles (iOS 26+), and chapter editing. Core player free — try Plus free for 7 days.
```

(119 characters)

**v1.0 alternate (if still on 1.0 in review):**

```
Core player free. Try Smart Rewind, Speech EQ, and subtitles free for 7 days with AudioPig Plus. Your library stays on your device.
```

---

## What's New (v1.1.2 — paste into App Store Connect)

```
• Voice Boost — clearer Off / Light / Balanced / Strong steps that are easy to hear on quiet narration
• Equalizer — turning EQ back on restores your last preset instead of resetting to Clear Speech
• Playback — audio enhancement level changes apply reliably while a book is playing
```

---

## What's New (v1.1.1 — paste into App Store Connect)

```
• Speech EQ — narration-tuned presets plus free Voice Boost levels for quiet passages
• Smart Rewind — set Look Far and Look Near windows with an intuitive dual-thumb range slider
• Subtitles — smoother auto-scroll when following playback; manual scroll pauses follow until you return
```

---

## What's New (v1.1 — paste into App Store Connect)

```
• Smart Rewind — Look Far and Look Near find silence before you drifted off so you can jump back to a natural break
• Live subtitles — on-device transcription near the playhead or for the whole book (iOS 26+; AudioPig Plus)
• Edit chapter titles, start times, and order from the chapter list
• New secret icons: Sher Pig (Sherlock Holmes) and Pig Sawyer (Tom Sawyer)
• New listening milestones at 2000 and 2500 hours
```

---

## Description

```
AudioPig is a beautiful audiobook player for the files you already own. Import MP3 and M4B audiobooks from the Files app, organize them in folders, and listen with a full-featured player designed for long sessions.

YOUR LIBRARY, ON YOUR DEVICE
• Import single or multiple MP3/M4B files from Files
• Merge multiple files into one book with a seamless chapter timeline
• Edit chapter titles, start times, and order after merging
• Search, multi-select, and organize with folders
• Edit title, author, and cover art

BUILT FOR LISTENING
• Speed from 0.5× to 3×
• Configurable skip forward and back intervals
• Scrub the whole book or the current chapter
• Sleep timer: minutes or end of chapter — survives app restarts
• Background audio and full lock screen controls

NEVER LOSE YOUR PLACE
• Playback position saved automatically
• Named bookmarks with export
• Smart Rewind: Look Far and Look Near scan silence before the playhead (AudioPig Plus — 7-day free trial)
• Live subtitles: on-device transcription, search, and export (AudioPig Plus; requires iOS 26 or later)

MOTIVATION WITHOUT THE NOISE
• Track total listening time and finished books
• Unlock alternate app icons as you listen — including secret achievement icons
• Celebrate finished books — optionally remove them when you're done

FREE TO START. PLUS WHEN YOU NEED IT.
Core playback, library, bookmarks, chapter editing, stats, and Apple Watch remote control are free. AudioPig Plus unlocks Smart Rewind, Speech EQ, and on-device subtitles (~$3.99/mo after a 7-day trial). Optional "Feed a Student" tips ($2.99 / $6.99 / $14.99) support indie development.

NO ACCOUNT. NO CLOUD.
AudioPig does not collect your data. Your audiobooks and listening history stay on your iPhone. Purchases are processed by Apple.

Supported formats: MP3 and M4B (non-DRM).
```

---

## Keywords (100 characters max, comma-separated, no spaces after commas)

```
audiobook,audiobooks,mp3,m4b,player,offline,local,books,listen,chapter,bookmark,captions
```

(93 characters)

---

## Category

- **Primary:** Books
- **Secondary:** Music (optional)

---

## Age Rating

Expect **4+** — no restricted content in the app itself. User-imported audio content is not rated by the app.

---

## Copyright

```
2026 Nitay Abuzaglo
```

---

## Support URL

Hosted on GitHub Pages:

```
https://audiopig.github.io/
```

## Marketing URL (optional)

Same as support URL.

---

## Privacy Policy URL

**Required.** Hosted copy (keep in sync with `docs/app-store/privacy-policy.html`):

```
https://audiopig.github.io/privacy-policy.html
```

---

## Terms of Use (EULA) URL

**Required for subscriptions.** Hosted copy (keep in sync with `docs/app-store/terms.html`). In App Store Connect → App Information → **License Agreement**, choose custom EULA and paste this URL:

```
https://audiopig.github.io/terms.html
```

---

## App Review Notes (for Apple reviewer)

```
AudioPig plays locally imported audio only. There is no sign-in, no server, and no sample content bundled.

To test:
1. Open the Library tab
2. Tap + → Import Files
3. Select one or more MP3 or M4B files from Files / iCloud Drive
4. Tap the book to play; use the player sheet for speed, bookmarks, sleep timer, Smart Rewind, and subtitles
5. Smart Rewind — tap Look Far or Look Near (without Plus, trial paywall appears; with StoreKit testing or sandbox Plus, analysis runs and shows break points)
6. Subtitles (iOS 26+ device recommended) — tap the captions button; long-press for generate near playhead or whole book. Speech recognition runs on-device only; first use may download a language pack on Wi‑Fi.
7. Chapters — open chapter list → Edit to rename chapters or adjust start times
8. Settings → AudioPig Plus / Feed a Student for subscription management and optional tips

StoreKit: Xcode scheme uses Audiopig.storekit for local testing. Sandbox account required on device for real IAP QA.

Apple Watch: the companion app supports remote iPhone playback (recent books, controls, chapters). The "Watch playback" option on the source picker is intentionally disabled (under-construction UI with hammer icon). On-Watch local library and iPhone-to-Watch transfer are not available.

Photo library, camera, and speech recognition are used only for cover art (your choice) and on-device subtitle transcription. Audio is not uploaded to our servers.

Encryption: app uses only standard HTTPS for system services; ITSAppUsesNonExemptEncryption is false.
```

---

## Screenshot Captions (optional, for marketing)

1. **Library** — "Your audiobooks, organized"
2. **Player** — "Full controls for long listens"
3. **Bookmarks** — "Save and export moments"
4. **Stats** — "Track progress, unlock icons"
5. **Folders** — "Group series and collections"

Capture on 6.7" (iPhone 15 Pro Max) and 6.5" if required by Connect at submit time.

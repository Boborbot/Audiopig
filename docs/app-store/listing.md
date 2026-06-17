# Audiopig — App Store Connect Listing Copy

Paste these fields into App Store Connect. Adjust tone if needed; all claims match current app behavior.

---

## App Name

```
Audiopig
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
Core player free. Try Find Paragraph Breaks free for 7 days with Audiopig Plus. Import, bookmark, and listen — your library stays on your device.
```

---

## Description

```
Audiopig is a beautiful audiobook player for the files you already own. Import MP3 and M4B audiobooks from the Files app, organize them in folders, and listen with a full-featured player designed for long sessions.

YOUR LIBRARY, ON YOUR DEVICE
• Import single files or entire folders from Files
• Merge multiple files into one book with a seamless chapter timeline
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
• Find paragraph breaks with smart silence detection (Audiopig Plus — 7-day free trial)

MOTIVATION WITHOUT THE NOISE
• Track total listening time and finished books
• Unlock alternate app icons as you listen
• Celebrate finished books — optionally remove them when you're done

FREE TO START. PLUS WHEN YOU NEED IT.
Core playback, library, bookmarks, stats, and Watch support are free. Audiopig Plus unlocks Find Paragraph Breaks (~$3.99/mo after a 7-day trial). Optional "Feed a Student" tips support indie development.

NO ACCOUNT. NO CLOUD.
Audiopig does not collect your data. Your audiobooks and listening history stay on your iPhone. Purchases are processed by Apple.

Supported formats: MP3 and M4B (non-DRM).
```

---

## Keywords (100 characters max, comma-separated, no spaces after commas)

```
audiobook,audiobooks,mp3,m4b,player,offline,local,books,listen,podcast,chapter,bookmark,sleep
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
https://boborbot.github.io/Audiopig/
```

## Marketing URL (optional)

Same as support URL.

---

## Privacy Policy URL

**Required.** Hosted copy (keep in sync with `docs/app-store/privacy-policy.html`):

```
https://boborbot.github.io/Audiopig/privacy-policy.html
```

---

## App Review Notes (for Apple reviewer)

```
Audiopig plays locally imported audio only. There is no sign-in, no server, and no sample content bundled.

To test:
1. Open the Library tab
2. Tap + → Import Files (or Import Folder)
3. Select an MP3 or M4B from Files / iCloud Drive
4. Tap the book to play; use the player sheet for speed, bookmarks, and sleep timer
5. Tap "Find Paragraph Breaks" — without Plus, a trial paywall appears; with StoreKit testing or sandbox Plus, analysis runs
6. Settings → Audiopig Plus / Feed a Student for subscription management and optional tips

StoreKit: Xcode scheme uses Audiopig.storekit for local testing. Sandbox account required on device for real IAP QA.

Microphone and camera are used only when the user chooses to set custom cover art from the camera in Edit Details. No audio is recorded.

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

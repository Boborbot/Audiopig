# AudioPig — Pre-Submission QA Checklist

Run on a **physical iPhone** (not just Simulator). Use iOS 17+ and at least one long audiobook (30+ minutes) plus a multi-file merged book.

Check each item; note device model and iOS version at the top.

```
Device: _______________   iOS: _______________   Date: _______________
```

---

## Install & First Launch

- [ ] App launches without crash on cold start
- [ ] Empty library state looks correct (no placeholder glitches)
- [ ] Tab bar shows Library, Stats, Settings

---

## Import

- [ ] Import single `.mp3` from Files app
- [ ] Import single `.m4b` from Files app
- [ ] Import multiple audio files at once
- [ ] Import entire folder (each file becomes a book or merges as expected)
- [ ] Cover art extracted from file metadata when present
- [ ] Title and author populated from metadata when present
- [ ] Import progress overlay appears and dismisses cleanly

---

## Library

- [ ] Search filters books and folders by title/author
- [ ] Multi-select mode: select several books, bulk delete works
- [ ] Merge: combine 2+ books into one multi-chapter timeline; chapter order correct
- [ ] Create folder from selection; books move into folder
- [ ] Folder drill-down shows contained books; back navigation works
- [ ] Delete folder (with confirmation); books removed or handled as designed
- [ ] Swipe/context actions: mark finished, mark unfinished, edit details, delete
- [ ] Edit Details: change title, author, cover (photo library, file, camera if available)
- [ ] Edit Folder: change title and cover art

---

## Playback

- [ ] Tap book → mini-player appears; tap mini-player → full player sheet
- [ ] Play / pause works
- [ ] Seek scrubber moves smoothly; position accurate after seek
- [ ] Toggle book vs chapter scrubber mode
- [ ] Skip forward / backward use Settings intervals
- [ ] Speed 0.5× through 3.0×; audio sounds correct at each step
- [ ] Chapter list: jump to chapter; correct file and position
- [ ] Playback continues with screen locked
- [ ] Lock screen controls: play/pause, skip, scrub
- [ ] Switch to another app; audio continues; return and UI state matches
- [ ] Kill app mid-play; relaunch → position restored near where you left off
- [ ] With orientation lock **off**, rotate to landscape: artwork+title on notch side, controls on opposite side; no scroll needed
- [ ] Landscape left and landscape right: artwork column follows the camera/notch edge
- [ ] Non-square cover art in landscape (tall and wide) looks correct in the artwork column
- [ ] All player controls reachable in landscape (scrubber, transport, speed, chapters, bookmarks, sleep timer, lull section)

---

## Bookmarks

- [ ] Add bookmark from player; appears in bookmark list
- [ ] Tap bookmark → seeks to timestamp
- [ ] Edit bookmark name and time
- [ ] Swipe delete bookmark
- [ ] Long-press bookmark browser works
- [ ] Export bookmarks (share sheet); file content readable

---

## Sleep Timer

- [ ] Set 5-minute timer; countdown visible; playback pauses when expired
- [ ] Set end-of-chapter timer; pauses at chapter boundary
- [ ] Kill app with active timer; relaunch → timer restored or cleared appropriately
- [ ] Turn timer off

---

## Lull Detection

- [ ] "Find Paragraph Breaks" runs without crash on a real chapter (with Plus or active trial)
- [ ] Without Plus: tap shows paywall sheet (button looks normal — no lock icon)
- [ ] Paywall: trial CTA when eligible; subscribe-only when not
- [ ] Restore Purchases from paywall and Settings works on a second device / fresh install
- [ ] After subscribing or starting trial, analysis runs on tap
- [ ] Results list shows plausible break points
- [ ] Tap result → seeks correctly
- [ ] Cancel mid-analysis works

---

## StoreKit / Monetization

Test with **Xcode StoreKit Configuration** (`Audiopig.storekit`) on Simulator, then **Sandbox** on a physical device before release.

### Local StoreKit Testing (Simulator)

- [ ] Scheme uses StoreKit configuration file (Edit Scheme → Run → Options)
- [ ] Settings → AudioPig Plus shows localized price
- [ ] Start 7-day trial from player paywall → Find Paragraph Breaks works
- [ ] Settings status shows trial end date or Active after subscribe
- [ ] Manage Subscription link opens Apple subscriptions page
- [ ] Restore Purchases refreshes entitlement state

### Feed a Student (consumables)

Coffee ($2.99), Lunch ($6.99), and Today's Rent ($14.99).

- [ ] All three tip tiers show prices in Settings
- [ ] Purchase tip → thank-you UI appears
- [ ] Same tip can be purchased again (consumable)

### Sandbox (physical device)

- [ ] Create Sandbox tester in App Store Connect
- [ ] Sign into Media & Purchases with sandbox account on device
- [ ] Purchase Plus subscription in sandbox; feature unlocks
- [ ] Restore on second install / device

---

## Finish & Celebrations

- [ ] Mark book finished → confetti celebration appears
- [ ] Celebration works from root library and from inside a folder
- [ ] Stats increment (if tracking enabled)
- [ ] Icon unlock overlay at milestone (or verify in Stats gallery)
- [ ] Auto-delete **off**: book stays after celebration
- [ ] Auto-delete **on**: after celebration, confirmation alert appears; Delete removes book; Keep retains it

---

## Stats Tab

- [ ] Total listening time updates after playback
- [ ] Finished books count matches manual marks
- [ ] Icon gallery shows tiers; switching icon works (if unlocked)
- [ ] Delete all reading data (Settings) clears stats

---

## Settings

- [ ] Appearance: system / light / dark each apply correctly
- [ ] Default speed, skip intervals persist after relaunch
- [ ] Track reading stats toggle behaves as expected
- [ ] AudioPig Plus section shows status, subscribe, manage, restore
- [ ] Feed a Student tips show prices and thank-you on purchase
- [ ] Apple Watch settings: artwork skip gestures toggle
- [ ] About section displays correctly

---

## Apple Watch

Test with iPhone paired and AudioPig installed on both.

### Source picker and remote playback (iPhone as source)

- [ ] Watch app launches; source picker shows **iPhone playback** and **Watch playback**
- [ ] Watch playback option shows under-construction state and is not tappable
- [ ] iPhone playback → recent books list loads from iPhone
- [ ] Tap book → player; play / pause works
- [ ] Skip forward / back; speed controls
- [ ] Chapter list loads and seek works
- [ ] Artwork skip gestures (if enabled in iPhone Settings → Apple Watch)
- [ ] iPhone unreachable → sensible connection message

### Watch local transfer (archived — skip until re-enabled)

Local library and Send to Watch are disabled (`WatchFeatures.localPlaybackEnabled`). Do not QA transfer flows until the feature is turned back on.

---

## Home Screen Widgets

- [ ] Add widgets from widget gallery; no crash
- [ ] Now-playing / recent books reflect current library state
- [ ] Listening stats widget updates after playback
- [ ] Hour-club widget shows progress toward next icon tier

## Lock Screen — Continue Listening

- [ ] Add **Continue Listening** circular widget (above/below clock); pig glyph and progress ring visible
- [ ] Progress ring matches last book position after playback
- [ ] Tap widget: last book plays, app opens to **Player** sheet
- [ ] iOS 18+: replace flashlight/camera corner with **Continue Listening** control; tap plays last book and opens player
- [ ] Works after force-quit (play a book once, quit app, tap widget/control)

---

## Regression / Edge Cases

- [ ] Very long book (2+ hours): scrub and chapter navigation stable
- [ ] Book with no embedded cover: placeholder color shows consistently
- [ ] Low storage / large import: no silent failure (error surfaced if any)
- [ ] Rotate device (if supported) — no layout breakage on player sheet
- [ ] AirPods / Bluetooth: play/pause from headphones works

---

## Sign-off

```
Blockers found: _______________
Ready for TestFlight: YES / NO
Tester: _______________
```


# Audiopig — Pre-Submission QA Checklist

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

- [ ] "Find Paragraph Breaks" runs without crash on a real chapter
- [ ] Results list shows plausible break points
- [ ] Tap result → seeks correctly
- [ ] Cancel mid-analysis works

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
- [ ] About section displays correctly

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

# Assets for Testing

Local audiobook fixtures for simulator and device QA. These files are **not committed to git** (they total ~1 GB).

## Included books

| File | Format |
|------|--------|
| Forbidden.m4b | M4B |
| The Age of Wood.mp3 | MP3 |
| Zeke Faux - Number Go Up, Inside Crypto's Wild Rise And Staggering Fall.mp3 | MP3 |
| Nuclear War.mp3 | MP3 |

## How it works

1. **Debug builds** copy this folder into the app bundle via the "Copy Test Assets" build phase.
2. On launch, `DevelopmentLibrarySeeder` imports any bundled file that is not already in your library (matched by filename).
3. After a simulator reset or fresh install, the four books reappear automatically on the next Debug run.

Release builds ignore this folder entirely.

## Restoring files

If you clone the repo on a new machine, copy your test `.mp3` / `.m4b` files back into this folder, then build and run (Debug).

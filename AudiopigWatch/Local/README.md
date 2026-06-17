# On-device Watch playback

> **Archived:** Local Watch library and iPhone → Watch transfer are disabled (`WatchFeatures.localPlaybackEnabled`). Remote iPhone playback from the Watch remains active.

The Watch app supports **remote** (iPhone) playback via `WatchPlaybackRouter`. Local playback code remains for a future release.

## Components (local — dormant)

- **`WatchLocalLibraryStore`** — manifest of books on Watch, `localURL(for:)`, LRU eviction (2 GB budget)
- **`LocalWatchPlaybackCoordinator`** — implements `WatchPlaybackCoordinating` with `WatchAudioEngine` (`AVPlayer`)
- **`WatchTransferService`** (iPhone) — stages files and sends via `WCSession.transferFile`

## iPhone → Watch transfer (dormant)

Re-enable `WatchFeatures.localPlaybackEnabled` when ready to ship transfer again.

## Watch UI

- **Playback source picker** — iPhone playback (active) vs Watch playback (under construction)
- **Recent books** — remote playback from iPhone

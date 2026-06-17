# On-device Watch playback

The Watch app supports **remote** (iPhone) and **local** (transferred) playback via `WatchPlaybackRouter`.

## Components

- **`WatchLocalLibraryStore`** — manifest of books on Watch, `localURL(for:)`, LRU eviction (2 GB budget)
- **`LocalWatchPlaybackCoordinator`** — implements `WatchPlaybackCoordinating` with `WatchAudioEngine` (`AVPlayer`)
- **`WatchTransferService`** (iPhone) — stages files and sends via `WCSession.transferFile`

## iPhone → Watch transfer

1. User sends from iPhone (context menu or Settings → Watch Library)
2. iPhone copies file to a temp path and calls `WCSession.transferFile` with `WatchTransferManifest` metadata
3. Watch ingests into `Application Support/TransferredBooks/<bookID>/`
4. Watch acknowledges library via `acknowledgeLocalBooks` command
5. Position syncs back to iPhone via `syncLocalPlaybackPosition`

## Watch UI

- **Playback source picker** — iPhone (recent books, remote) vs Watch (local library)
- **+** on Watch library opens import instructions (phone-only transfer)

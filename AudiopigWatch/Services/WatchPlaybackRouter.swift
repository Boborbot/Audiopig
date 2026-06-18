//
//  WatchPlaybackRouter.swift
//  AudiopigWatch
//

import Foundation

@MainActor
final class WatchPlaybackRouter: WatchPlaybackCoordinating {
    private let remote: RemoteWatchPlaybackCoordinator
    private let local: LocalWatchPlaybackCoordinator

    private var activeSource: WatchPlaybackSource = .remote
    private var snapshotHandler: ((WatchPlaybackSnapshot) -> Void)?
    private var chaptersHandler: ((WatchChaptersPayload) -> Void)?
    /// When true, iPhone playback snapshots must not take over the Watch UI or stop local playback.
    private(set) var prefersLocalPlayback = false

    var snapshot: WatchPlaybackSnapshot? {
        activeCoordinator.snapshot
    }

    var isReachable: Bool {
        switch activeSource {
        case .remote: remote.isReachable
        case .local: local.isReachable
        }
    }

    init(remote: RemoteWatchPlaybackCoordinator, local: LocalWatchPlaybackCoordinator) {
        self.remote = remote
        self.local = local

        remote.setSnapshotHandler { [weak self] snap in
            guard let self, snap.source == .remote else { return }
            guard !self.prefersLocalPlayback else { return }

            if let bookID = snap.bookID {
                if self.activeSource == .local {
                    self.local.stopPlaybackIfActive()
                }
                self.activeSource = .remote
                self.snapshotHandler?(snap)
                return
            }

            if self.activeSource == .remote {
                self.snapshotHandler?(snap)
            }
        }

        local.setSnapshotHandler { [weak self] snap in
            guard let self else { return }
            if snap.bookID != nil { self.activeSource = .local }
            if self.activeSource == .local {
                self.snapshotHandler?(snap)
            }
        }

        local.setChaptersHandler { [weak self] payload in
            guard let self, self.activeSource == .local else { return }
            self.chaptersHandler?(payload)
        }
    }

    func preferLocalPlayback(_ preferred: Bool) {
        prefersLocalPlayback = preferred
        if preferred {
            activeSource = .local
        }
    }

    func setSnapshotHandler(_ handler: @escaping (WatchPlaybackSnapshot) -> Void) {
        snapshotHandler = handler
        if let snap = snapshot {
            handler(snap)
        }
    }

    func setChaptersHandler(_ handler: @escaping (WatchChaptersPayload) -> Void) {
        chaptersHandler = handler
    }

    func send(_ command: WatchCommand) async -> WatchCommandResult {
        switch command {
        case .loadLocalBook:
            prefersLocalPlayback = true
            activeSource = .local
            return await local.send(command)

        case .loadBook:
            prefersLocalPlayback = false
            local.stopPlaybackIfActive()
            activeSource = .remote
            return await remote.send(command)

        case .requestRecentBooks, .requestSnapshot, .togglePlayPause, .play, .pause,
             .skipForward, .skipBackward, .setSpeed, .setVolume,
             .seekToChapterIndex, .seekToChapter, .setArtworkSkipGesturesEnabled,
             .setWatchArtworkViewMode:
            return await activeCoordinator.send(command)

        case .analyzeLulls, .seekToLull:
            guard activeSource == .remote else {
                return .failure("Available for iPhone playback only.")
            }
            return await remote.send(command)

        case .requestLocalBooks, .deleteLocalBook:
            return await local.send(command)

        case .syncLocalPlaybackPosition, .acknowledgeLocalBooks, .reportTransferIngestFailed:
            return await remote.send(command)
        }
    }

    private var activeCoordinator: any WatchPlaybackCoordinating {
        switch activeSource {
        case .remote: remote
        case .local: local
        }
    }
}

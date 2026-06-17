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
            guard let self else { return }
            if self.activeSource == .remote || snap.bookID == nil {
                if snap.bookID != nil { self.activeSource = .remote }
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
            activeSource = .local
            return await local.send(command)

        case .loadBook:
            local.stopPlaybackIfActive()
            activeSource = .remote
            return await remote.send(command)

        case .requestRecentBooks, .requestSnapshot, .togglePlayPause, .play, .pause,
             .skipForward, .skipBackward, .setSpeed, .setVolume,
             .seekToChapterIndex, .seekToChapter, .setArtworkSkipGesturesEnabled:
            return await activeCoordinator.send(command)

        case .requestLocalBooks, .deleteLocalBook:
            return await local.send(command)

        case .syncLocalPlaybackPosition, .acknowledgeLocalBooks:
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

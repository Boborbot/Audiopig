//
//  RemoteWatchPlaybackCoordinator.swift
//  AudiopigWatch
//

import Foundation

@MainActor
final class RemoteWatchPlaybackCoordinator: WatchPlaybackCoordinating {
    private let client: WatchConnectivityClient

    var snapshot: WatchPlaybackSnapshot? { client.latestSnapshot }
    var isReachable: Bool { client.isReachable }

    init(client: WatchConnectivityClient) {
        self.client = client
    }

    func send(_ command: WatchCommand) async -> WatchCommandResult {
        await client.send(command)
    }

    func setSnapshotHandler(_ handler: @escaping (WatchPlaybackSnapshot) -> Void) {
        client.setSnapshotHandler(handler)
    }
}

//
//  AudiopigWatchApp.swift
//  AudiopigWatch
//

import SwiftUI

@main
struct AudiopigWatchApp: App {
    private let connectivityClient = WatchConnectivityClient()
    private let router: WatchPlaybackRouter
    private let playerViewModel: WatchPlayerViewModel
    private let libraryViewModel: WatchLibraryViewModel

    init() {
        let remoteCoordinator = RemoteWatchPlaybackCoordinator(client: connectivityClient)
        let localStore = WatchLocalLibraryStore()
        let localCoordinator = LocalWatchPlaybackCoordinator(
            store: localStore,
            engine: WatchAudioEngine(),
            client: connectivityClient
        )
        router = WatchPlaybackRouter(remote: remoteCoordinator, local: localCoordinator)
        playerViewModel = WatchPlayerViewModel(coordinator: router, client: connectivityClient)
        libraryViewModel = WatchLibraryViewModel(coordinator: router, client: connectivityClient)
        connectivityClient.configure(
            localStore: localStore,
            localCoordinator: localCoordinator,
            acceptsTransfers: WatchFeatures.localPlaybackEnabled
        )
        connectivityClient.activate()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchRootView(
                    playerViewModel: playerViewModel,
                    libraryViewModel: libraryViewModel
                )
            }
        }
    }
}

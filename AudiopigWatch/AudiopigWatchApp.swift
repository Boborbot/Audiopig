//
//  AudiopigWatchApp.swift
//  AudiopigWatch
//

import SwiftUI

@main
struct AudiopigWatchApp: App {
    private let connectivityClient = WatchConnectivityClient()
    private let localStore = WatchLocalLibraryStore()
    private let router: WatchPlaybackRouter
    private let playerViewModel: WatchPlayerViewModel
    private let libraryViewModel: WatchLibraryViewModel
    private let localLibraryViewModel: WatchLocalLibraryViewModel

    init() {
        let remoteCoordinator = RemoteWatchPlaybackCoordinator(client: connectivityClient)
        let localCoordinator = LocalWatchPlaybackCoordinator(
            store: localStore,
            engine: WatchAudioEngine(),
            client: connectivityClient
        )
        router = WatchPlaybackRouter(remote: remoteCoordinator, local: localCoordinator)
        playerViewModel = WatchPlayerViewModel(coordinator: router, client: connectivityClient)
        libraryViewModel = WatchLibraryViewModel(coordinator: router, client: connectivityClient)
        localLibraryViewModel = WatchLocalLibraryViewModel(
            store: localStore,
            coordinator: router,
            client: connectivityClient
        )
        connectivityClient.configure(localStore: localStore, localCoordinator: localCoordinator)
        connectivityClient.activate()
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchRootView(
                    playerViewModel: playerViewModel,
                    libraryViewModel: libraryViewModel,
                    localLibraryViewModel: localLibraryViewModel
                )
            }
        }
    }
}

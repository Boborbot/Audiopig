//
//  AudiopigWatchApp.swift
//  AudiopigWatch
//

import SwiftUI
import Foundation

@main
struct AudiopigWatchApp: App {
    private let connectivityClient = WatchConnectivityClient()
    private let router: WatchPlaybackRouter
    private let playerViewModel: WatchPlayerViewModel
    private let libraryViewModel: WatchLibraryViewModel
    private let localLibraryViewModel: WatchLocalLibraryViewModel
#if DEBUG
    private let smokeTestPlayerViewModel: WatchPlayerViewModel?
#endif

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
        localLibraryViewModel = WatchLocalLibraryViewModel(
            store: localStore,
            coordinator: localCoordinator,
            client: connectivityClient
        )
#if DEBUG
        if Self.smokeTestPage != nil {
            smokeTestPlayerViewModel = WatchPlayerViewModel(
                coordinator: WatchPlayerSmokeTestCoordinator(),
                client: connectivityClient
            )
        } else {
            smokeTestPlayerViewModel = nil
        }
#endif
        connectivityClient.configure(
            localStore: localStore,
            localCoordinator: localCoordinator,
            acceptsTransfers: WatchFeatures.localPlaybackEnabled
        )
        connectivityClient.activate()
    }

    var body: some Scene {
        WindowGroup {
#if DEBUG
            if let smokeTestPage = Self.smokeTestPage,
               let smokeTestPlayerViewModel {
                WatchPlayerSmokeTestView(
                    viewModel: smokeTestPlayerViewModel,
                    page: smokeTestPage
                )
            } else {
                rootView
            }
#else
            rootView
#endif
        }
    }

    private var rootView: some View {
        WatchRootView(
            playerViewModel: playerViewModel,
            libraryViewModel: libraryViewModel,
            localLibraryViewModel: localLibraryViewModel
        )
    }

#if DEBUG
    private static var smokeTestPage: WatchPlayerPageKind? {
        let prefix = "--watch-player-smoke-page="
        guard let argument = ProcessInfo.processInfo.arguments.first(where: {
            $0.hasPrefix(prefix)
        }) else {
            return nil
        }

        return WatchPlayerPageKind(rawValue: String(argument.dropFirst(prefix.count)))
    }
#endif
}

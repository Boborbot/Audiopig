//
//  WatchLibraryViewModel.swift
//  AudiopigWatch
//

import Foundation
import UIKit
import Combine

@MainActor
final class WatchLibraryViewModel: ObservableObject {
    @Published private(set) var books: [WatchBookSummary] = []
    @Published private(set) var connectionState: WatchConnectionState = .activating
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let coordinator: any WatchPlaybackCoordinating
    private let client: WatchConnectivityClient

    init(coordinator: any WatchPlaybackCoordinating, client: WatchConnectivityClient) {
        self.coordinator = coordinator
        self.client = client

        client.setRecentBooksHandler { [weak self] payload in
            self?.books = payload.books
            self?.isLoading = false
        }

        if let cached = client.latestRecentBooks {
            books = cached.books
        }
        connectionState = client.connectionState

        client.setConnectionStateHandler { [weak self] state in
            guard let self else { return }
            let wasReachable = self.connectionState == .reachable
            self.connectionState = state
            if !wasReachable, state == .reachable {
                Task { await self.refresh() }
            }
        }
    }

    func onAppear() async {
        connectionState = client.connectionState
        await refresh()
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        connectionState = client.connectionState

        let result = await coordinator.send(.requestRecentBooks)
        connectionState = client.connectionState

        if let payload = result.recentBooks {
            books = payload.books
        }

        isLoading = false

        if !result.success {
            errorMessage = result.errorMessage ?? client.connectionErrorMessage
            WatchHaptics.error()
        }
    }

    func selectBook(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result = await coordinator.send(.loadBook(bookID: id, autoPlay: true))
        connectionState = client.connectionState

        if result.success {
            WatchHaptics.play()
            return true
        }

        errorMessage = result.errorMessage ?? client.connectionErrorMessage
        WatchHaptics.error()
        return false
    }

    var connectionStatusMessage: String? {
        switch connectionState {
        case .companionNotInstalled:
            return "Install \(Brand.displayName) on iPhone"
        case .notReachable:
            return "Open \(Brand.displayName) on iPhone"
        case .activating:
            return "Connecting…"
        case .reachable:
            return nil
        }
    }
}

extension WatchBookSummary {
    var thumbnailImage: UIImage? {
        guard let data = thumbnailJPEG else { return nil }
        return UIImage(data: data)
    }
}

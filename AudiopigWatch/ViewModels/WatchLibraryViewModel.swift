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
        refreshTask?.cancel()
        refreshTask = Task {
            isLoading = true
            errorMessage = nil
            connectionState = client.connectionState

            guard !Task.isCancelled else { return }

            let result = await coordinator.send(.requestRecentBooks)
            connectionState = client.connectionState

            guard !Task.isCancelled else { return }

            if let payload = result.recentBooks {
                books = payload.books
            }

            isLoading = false

            if !result.success {
                errorMessage = result.errorMessage ?? client.connectionErrorMessage
                WatchHaptics.error()
            }
        }
        await refreshTask?.value
    }

    @Published private(set) var isSelectingBook = false

    private var refreshTask: Task<Void, Never>?

    func selectBook(id: UUID) async -> Bool {
        refreshTask?.cancel()
        isSelectingBook = true
        defer { isSelectingBook = false }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        if let snapshot = coordinator.snapshot,
           snapshot.bookID == id,
           snapshot.source == .remote {
            switch snapshot.playbackState {
            case .playing, .loading:
                WatchHaptics.play()
                return true
            case .paused, .finished, .idle:
                let result = await coordinator.send(.play)
                connectionState = client.connectionState
                if result.success {
                    WatchHaptics.play()
                    return true
                }
                errorMessage = result.errorMessage ?? client.connectionErrorMessage
                WatchHaptics.error()
                return false
            case .failed:
                break
            }
        }

        let result = await coordinator.send(.loadBook(bookID: id, autoPlay: true))
        connectionState = client.connectionState

        if await waitForRemoteBook(id: id) {
            WatchHaptics.play()
            return true
        }

        errorMessage = result.errorMessage ?? client.connectionErrorMessage
        WatchHaptics.error()
        return false
    }

    private func waitForRemoteBook(id: UUID) async -> Bool {
        for _ in 0..<45 {
            if let snapshot = coordinator.snapshot, snapshot.bookID == id {
                switch snapshot.playbackState {
                case .playing, .paused:
                    return true
                case .loading:
                    break
                case .idle, .finished, .failed:
                    return false
                }
            }
            try? await Task.sleep(for: .milliseconds(200))
        }
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

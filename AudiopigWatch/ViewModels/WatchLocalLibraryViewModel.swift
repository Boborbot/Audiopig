//
//  WatchLocalLibraryViewModel.swift
//  AudiopigWatch
//

import Foundation
import Combine

@MainActor
final class WatchLocalLibraryViewModel: ObservableObject {
    @Published private(set) var books: [WatchBookSummary] = []
    @Published private(set) var usedBytes: Int64 = 0
    @Published private(set) var budgetBytes: Int64 = WatchStorageBudget.defaultBudgetBytes
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let store: any WatchLocalLibraryStoring
    private let coordinator: any WatchPlaybackCoordinating

    init(store: any WatchLocalLibraryStoring, coordinator: any WatchPlaybackCoordinating, client: WatchConnectivityClient) {
        self.store = store
        self.coordinator = coordinator

        client.setLocalBooksHandler { [weak self] _ in
            self?.refreshFromStore()
        }
        refreshFromStore()
    }

    func onAppear() {
        refreshFromStore()
    }

    func refreshFromStore() {
        let payload = store.localBooksPayload()
        books = payload.books
        usedBytes = payload.usedBytes
        budgetBytes = payload.budgetBytes
    }

    func selectBook(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let result = await coordinator.send(.loadLocalBook(bookID: id, autoPlay: true))
        if result.success {
            WatchHaptics.play()
            return true
        }

        errorMessage = result.errorMessage ?? "Could not load book."
        WatchHaptics.error()
        return false
    }

    var storageLabel: String {
        let usedMB = Double(usedBytes) / 1_048_576
        let budgetMB = Double(budgetBytes) / 1_048_576
        return String(format: "%.0f / %.0f MB", usedMB, budgetMB)
    }
}
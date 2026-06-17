//
//  WatchLibraryManagementViewModel.swift
//  Audiopig
//

import Foundation
import Observation

@MainActor
@Observable
final class WatchLibraryManagementViewModel {
    private(set) var audiobooks: [Audiobook] = []
    var selectedIDs: Set<UUID> = []

    private let libraryViewModel: LibraryViewModel

    init(libraryViewModel: LibraryViewModel) {
        self.libraryViewModel = libraryViewModel
        refresh()
    }

    var usedBytes: Int64 {
        _ = libraryViewModel.watchTransferStateRevision
        return libraryViewModel.watchLocalBooks?.usedBytes ?? 0
    }

    var budgetBytes: Int64 {
        _ = libraryViewModel.watchTransferStateRevision
        return libraryViewModel.watchLocalBooks?.budgetBytes ?? WatchStorageBudget.defaultBudgetBytes
    }

    var storageLabel: String {
        _ = libraryViewModel.watchTransferStateRevision
        let usedMB = Double(usedBytes) / 1_048_576
        let budgetMB = Double(budgetBytes) / 1_048_576
        return String(format: "%.0f / %.0f MB on Watch", usedMB, budgetMB)
    }

    var transferStateRevision: UInt64 {
        libraryViewModel.watchTransferStateRevision
    }

    var hasActiveTransfers: Bool {
        _ = libraryViewModel.watchTransferStateRevision
        return audiobooks.contains {
            if case .transferring = libraryViewModel.watchStatus(for: $0) { return true }
            return false
        }
    }

    func refresh() {
        audiobooks = libraryViewModel.sortedAudiobooks(libraryViewModel.audiobooks)
    }

    func status(for audiobook: Audiobook) -> WatchBookTransferStatus {
        _ = libraryViewModel.watchTransferStateRevision
        return libraryViewModel.watchStatus(for: audiobook)
    }

    func isSelected(_ audiobook: Audiobook) -> Bool {
        selectedIDs.contains(audiobook.id)
    }

    func toggleSelection(_ audiobook: Audiobook) {
        if selectedIDs.contains(audiobook.id) {
            selectedIDs.remove(audiobook.id)
        } else {
            selectedIDs.insert(audiobook.id)
        }
    }

    func transferSelected() async {
        let books = audiobooks.filter { selectedIDs.contains($0.id) }
        for book in books {
            switch status(for: book) {
            case .notOnWatch, .failed:
                await libraryViewModel.sendToWatch(book)
            case .onWatch, .transferring, .unavailable:
                break
            }
        }
        selectedIDs.removeAll()
    }

    func removeFromWatch(_ audiobook: Audiobook) async {
        await libraryViewModel.removeFromWatch(audiobook)
    }

    func cancelTransfer(_ audiobook: Audiobook) {
        libraryViewModel.cancelWatchTransfer(audiobook)
    }

    func transfer(_ audiobook: Audiobook) async {
        await libraryViewModel.sendToWatch(audiobook)
    }

    func syncWatchLibrary() async {
        await libraryViewModel.syncWatchLocalBooks()
    }
}

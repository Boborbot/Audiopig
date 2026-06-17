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
        libraryViewModel.watchLocalBooks?.usedBytes ?? 0
    }

    var budgetBytes: Int64 {
        libraryViewModel.watchLocalBooks?.budgetBytes ?? WatchStorageBudget.defaultBudgetBytes
    }

    var storageLabel: String {
        let usedMB = Double(usedBytes) / 1_048_576
        let budgetMB = Double(budgetBytes) / 1_048_576
        return String(format: "%.0f / %.0f MB on Watch", usedMB, budgetMB)
    }

    func refresh() {
        audiobooks = libraryViewModel.sortedAudiobooks(libraryViewModel.audiobooks)
    }

    func status(for audiobook: Audiobook) -> WatchBookTransferStatus {
        libraryViewModel.watchStatus(for: audiobook)
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
        for book in books where status(for: book) == .notOnWatch {
            await libraryViewModel.sendToWatch(book)
        }
        selectedIDs.removeAll()
    }

    func removeFromWatch(_ audiobook: Audiobook) async {
        await libraryViewModel.removeFromWatch(audiobook)
    }

    func transfer(_ audiobook: Audiobook) async {
        await libraryViewModel.sendToWatch(audiobook)
    }
}

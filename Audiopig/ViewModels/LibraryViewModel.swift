//
//  LibraryViewModel.swift
//  Audiopig
//

import Observation
import SwiftData
import Foundation

@MainActor
@Observable
final class LibraryViewModel {

    // MARK: - Library State

    private(set) var audiobooks: [Audiobook] = []
    private(set) var isMerging: Bool = false
    private(set) var isImporting: Bool = false
    private(set) var errorMessage: String?

    // MARK: - Search

    var searchText: String = ""
    var isSearchActive: Bool = false

    var filteredAudiobooks: [Audiobook] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return audiobooks }
        let query = trimmed.lowercased()
        return audiobooks.filter { book in
            book.title.lowercased().contains(query)
                || book.author.lowercased().contains(query)
                || book.fileURL.deletingPathExtension().lastPathComponent.lowercased().contains(query)
        }
    }

    // MARK: - Selection State

    private(set) var isSelectionModeActive: Bool = false
    private(set) var selectedIDs: Set<UUID> = []

    // MARK: - Sheet / Modal State

    var isMergeSheetPresented: Bool = false
    var pendingMergeTitle: String = ""
    var isBulkDeleteConfirmationPresented: Bool = false
    var isSwipeDeleteConfirmationPresented: Bool = false

    // MARK: - Player Sub-ViewModel

    let playerViewModel: PlayerViewModel

    // MARK: - Computed

    var canMergeSelected: Bool { selectedIDs.count >= 2 }
    var canDeleteSelected: Bool { !selectedIDs.isEmpty }
    var selectedCount: Int { selectedIDs.count }

    func isSelected(_ audiobook: Audiobook) -> Bool {
        selectedIDs.contains(audiobook.id)
    }

    private var selectedAudiobooks: [Audiobook] {
        audiobooks.filter { selectedIDs.contains($0.id) }
    }

    // MARK: - Finish Celebration

    /// Set when the user marks a book finished — drives the pig celebration overlay.
    var celebratedBook: Audiobook?

    // MARK: - Pending Delete

    private var pendingSwipeDeleteIndexSet: IndexSet?
    private var pendingSwipeDeleteBook: Audiobook?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let libraryManager: any LibraryManagerProtocol

    // MARK: - Init

    init(
        modelContext: ModelContext,
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        appSettings: AppSettings
    ) {
        self.modelContext = modelContext
        self.libraryManager = libraryManager
        self.playerViewModel = PlayerViewModel(
            audioEngine: audioEngine,
            modelContext: modelContext,
            appSettings: appSettings
        )
        fetchAudiobooks()
    }

    // MARK: - Fetch

    func fetchAudiobooks() {
        let descriptor = FetchDescriptor<Audiobook>(
            sortBy: [SortDescriptor(\.title, comparator: .localizedStandard)]
        )
        audiobooks = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Player Navigation

    /// Loads the audiobook into the engine and starts playback; the MiniPlayer appears automatically.
    func openPlayer(for audiobook: Audiobook) {
        Task {
            await playerViewModel.loadAudiobook(audiobook, autoPlay: true)
        }
    }

    // MARK: - Selection

    func toggleSelectionMode() {
        isSelectionModeActive.toggle()
        if !isSelectionModeActive { selectedIDs.removeAll() }
        if isSelectionModeActive { clearSearch() }
    }

    func toggleSelection(_ audiobook: Audiobook) {
        if selectedIDs.contains(audiobook.id) {
            selectedIDs.remove(audiobook.id)
        } else {
            selectedIDs.insert(audiobook.id)
        }
    }

    // MARK: - Finish

    /// Marks a book as manually finished and fires the pig celebration.
    func markFinished(_ audiobook: Audiobook) {
        audiobook.isManuallyFinished = true
        saveContext(errorContext: "mark finished")
        celebratedBook = audiobook
    }

    /// Unmarks a book so it is no longer manually finished.
    func markUnfinished(_ audiobook: Audiobook) {
        audiobook.isManuallyFinished = false
        saveContext(errorContext: "mark unfinished")
    }

    /// Clears the celebration overlay.
    func dismissCelebration() {
        celebratedBook = nil
    }

    // MARK: - Delete

    /// Requests confirmation before bulk-deleting all currently selected books.
    func requestBulkDelete() {
        guard canDeleteSelected else { return }
        isBulkDeleteConfirmationPresented = true
    }

    /// Called after the user confirms the bulk delete alert.
    func confirmBulkDelete() {
        selectedAudiobooks.forEach { delete($0) }
        isSelectionModeActive = false
        selectedIDs.removeAll()
    }

    /// Stores the swipe-delete index set and requests confirmation before executing.
    func requestDelete(at indexSet: IndexSet) {
        pendingSwipeDeleteIndexSet = indexSet
        isSwipeDeleteConfirmationPresented = true
    }

    /// Stores the book from a swipe action and requests confirmation before deleting.
    func requestDelete(_ audiobook: Audiobook) {
        pendingSwipeDeleteBook = audiobook
        isSwipeDeleteConfirmationPresented = true
    }

    /// Called after the user confirms the swipe delete alert.
    func confirmSwipeDelete() {
        if let book = pendingSwipeDeleteBook {
            pendingSwipeDeleteBook = nil
            delete(book)
            return
        }
        guard let indexSet = pendingSwipeDeleteIndexSet else { return }
        pendingSwipeDeleteIndexSet = nil
        indexSet.compactMap { audiobooks[safe: $0] }.forEach { delete($0) }
    }

    private func delete(_ audiobook: Audiobook) {
        try? libraryManager.deleteAudiobookFile(at: audiobook.fileURL)
        modelContext.delete(audiobook)
        saveContext(errorContext: "delete audiobook")
        fetchAudiobooks()
    }

    // MARK: - Import

    /// Imports one or more security-scoped file URLs, persisting each into the library.
    func importFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isImporting = true

        var failedNames: [String] = []

        for url in urls {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            do {
                _ = try await libraryManager.importAndPersist(from: url, in: modelContext)
            } catch {
                failedNames.append(url.deletingPathExtension().lastPathComponent)
            }
        }

        isImporting = false
        fetchAudiobooks()

        if !failedNames.isEmpty {
            errorMessage = "Could not import: \(failedNames.joined(separator: ", "))"
        }
    }

    /// Scans a security-scoped folder URL for supported audio files and imports each one.
    func importFolder(_ url: URL) async {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        isImporting = true
        defer {
            isImporting = false
            fetchAudiobooks()
        }

        let discoveredMetadata: [AudiobookImportMetadata]
        do {
            discoveredMetadata = try await libraryManager.scanDirectory(at: url)
        } catch {
            errorMessage = "Could not read the selected folder."
            return
        }

        var failedNames: [String] = []
        for metadata in discoveredMetadata {
            do {
                _ = try await libraryManager.importAndPersist(from: metadata.fileURL, in: modelContext)
            } catch {
                failedNames.append(metadata.title)
            }
        }

        if !failedNames.isEmpty {
            errorMessage = "Could not import: \(failedNames.joined(separator: ", "))"
        }
    }

    // MARK: - Merge

    func mergeSelected() async {
        let title = pendingMergeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canMergeSelected, !title.isEmpty else { return }

        isMerging = true
        defer {
            isMerging = false
            isMergeSheetPresented = false
            pendingMergeTitle = ""
        }

        do {
            _ = try libraryManager.merge(
                audiobooks: selectedAudiobooks,
                intoTitle: title,
                in: modelContext
            )
            isSelectionModeActive = false
            selectedIDs.removeAll()
            fetchAudiobooks()
        } catch {
            errorMessage = "Merge failed. Please try again."
        }
    }

    // MARK: - Search

    func clearSearch() {
        searchText = ""
        isSearchActive = false
    }

    // MARK: - Error Handling

    func clearError() { errorMessage = nil }

    func reportError(_ message: String) { errorMessage = message }

    // MARK: - Private

    private func saveContext(errorContext: String) {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to \(errorContext)."
        }
    }
}

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
    private(set) var folders: [Folder] = []
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

    /// Items shown in the root library list.
    /// Normal mode: folders + root-level books (no folder) interleaved by title.
    /// Search mode: all matching books regardless of folder, no folder rows.
    var libraryItems: [LibraryItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSearchActive && !trimmed.isEmpty {
            let query = trimmed.lowercased()
            return audiobooks.filter { book in
                book.title.lowercased().contains(query)
                    || book.author.lowercased().contains(query)
                    || book.fileURL.deletingPathExtension().lastPathComponent.lowercased().contains(query)
            }.map { .audiobook($0) }
        }
        let bookItems = audiobooks.filter { $0.folder == nil }.map { LibraryItem.audiobook($0) }
        let folderItems = folders.map { LibraryItem.folder($0) }
        return (bookItems + folderItems).sorted {
            $0.sortTitle.localizedCaseInsensitiveCompare($1.sortTitle) == .orderedAscending
        }
    }

    // MARK: - Selection State

    private(set) var isSelectionModeActive: Bool = false
    private(set) var selectedIDs: Set<UUID> = []

    // MARK: - Sheet / Modal State

    var isMergeSheetPresented: Bool = false
    var pendingMergeTitle: String = ""
    var isFolderSheetPresented: Bool = false
    var pendingFolderTitle: String = ""
    var isBulkDeleteConfirmationPresented: Bool = false
    var isSwipeDeleteConfirmationPresented: Bool = false

    /// Ordered list of audiobooks to combine, populated when the sheet opens.
    /// The user can reorder these before confirming; the order is respected by merge().
    private(set) var mergeOrder: [Audiobook] = []

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

    /// Set when the user marks a book finished — drives the confetti overlay.
    var celebratedBook: Audiobook?

    /// Set when finishing a book pushes total hours over a new icon tier threshold.
    /// Drives the `IconUnlockOverlay` in `LibraryView`.
    var newlyUnlockedIconTier: AppIconTier?

    /// When `autoDeleteOnFinish` is on, the book is held here until the celebration
    /// completes so the overlay can still reference its title during the animation.
    private var pendingAutoDeleteBook: Audiobook?

    // MARK: - Pending Delete

    private var pendingSwipeDeleteIndexSet: IndexSet?
    private var pendingSwipeDeleteBook: Audiobook?

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let libraryManager: any LibraryManagerProtocol
    private let appSettings: AppSettings
    let appIconManager: AppIconManager

    // MARK: - Init

    init(
        modelContext: ModelContext,
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        appSettings: AppSettings,
        appIconManager: AppIconManager
    ) {
        self.modelContext = modelContext
        self.libraryManager = libraryManager
        self.appSettings = appSettings
        self.appIconManager = appIconManager
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

        let folderDescriptor = FetchDescriptor<Folder>(
            sortBy: [SortDescriptor(\.title, comparator: .localizedStandard)]
        )
        folders = (try? modelContext.fetch(folderDescriptor)) ?? []
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

    /// Marks a book as manually finished, optionally records the event, and fires the celebration.
    /// Idempotent — calling it on an already-finished book is a no-op.
    func markFinished(_ audiobook: Audiobook) {
        guard !audiobook.isManuallyFinished else { return }

        audiobook.isManuallyFinished = true

        if appSettings.trackReadingStats {
            let record = FinishedRecord(
                audiobookID:       audiobook.id,
                title:             audiobook.title,
                author:            audiobook.author,
                totalSeconds:      audiobook.duration,
                listenedSeconds:   audiobook.currentPlaybackTime,
                chapterCount:      audiobook.chapters.count,
                wasManuallyMarked: true
            )
            modelContext.insert(record)
        }

        saveContext(errorContext: "mark finished")
        checkIconUnlock()

        if appSettings.autoDeleteOnFinish {
            pendingAutoDeleteBook = audiobook
        }

        celebratedBook = audiobook
    }

    /// Computes total finished-book listening time and asks `AppIconManager`
    /// whether any new tier is now unlocked. Sets `newlyUnlockedIconTier` if so.
    private func checkIconUnlock() {
        let records    = (try? modelContext.fetch(FetchDescriptor<FinishedRecord>())) ?? []
        let allBooks   = (try? modelContext.fetch(FetchDescriptor<Audiobook>()))      ?? []
        let libraryIDs = Set(allBooks.map(\.id))

        let finishedLibraryTime = allBooks
            .filter(\.isFinished)
            .reduce(0.0) { $0 + $1.currentPlaybackTime }
        let finishedDeletedTime = records
            .filter { !libraryIDs.contains($0.audiobookID) }
            .reduce(0.0) { $0 + $1.listenedSeconds }

        let total = finishedLibraryTime + finishedDeletedTime
        newlyUnlockedIconTier = appIconManager.checkForNewUnlocks(totalFinishedSeconds: total)
    }

    /// Clears the icon-unlock overlay.
    func dismissIconUnlock() {
        newlyUnlockedIconTier = nil
    }

    /// Unmarks a book so it is no longer manually finished.
    func markUnfinished(_ audiobook: Audiobook) {
        audiobook.isManuallyFinished = false
        saveContext(errorContext: "mark unfinished")
    }

    /// Clears the celebration overlay; if auto-delete is pending, deletes the book now.
    func dismissCelebration() {
        celebratedBook = nil
        if let book = pendingAutoDeleteBook {
            pendingAutoDeleteBook = nil
            delete(book)
        }
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

    /// Opens the combine sheet, snapshotting the current selection into mergeOrder
    /// so the user can drag to set the desired playback order before confirming.
    func presentMergeSheet() {
        mergeOrder = selectedAudiobooks
        isMergeSheetPresented = true
    }

    func moveMergeBook(from source: IndexSet, to destination: Int) {
        guard let sourceIndex = source.first else { return }
        let item = mergeOrder.remove(at: sourceIndex)
        let insertAt = destination > sourceIndex ? destination - 1 : destination
        mergeOrder.insert(item, at: min(insertAt, mergeOrder.count))
    }

    func mergeSelected() async {
        let title = pendingMergeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canMergeSelected, !title.isEmpty else { return }

        isMerging = true
        defer {
            isMerging = false
            isMergeSheetPresented = false
            pendingMergeTitle = ""
            mergeOrder = []
        }

        do {
            _ = try libraryManager.merge(
                audiobooks: mergeOrder,
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

    // MARK: - Folder

    func presentFolderSheet() {
        isFolderSheetPresented = true
    }

    func createFolder() {
        let title = pendingFolderTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, canDeleteSelected else { return }

        let folder = Folder(title: title)
        modelContext.insert(folder)
        for book in selectedAudiobooks {
            book.folder = folder
        }
        saveContext(errorContext: "create folder")

        isFolderSheetPresented = false
        pendingFolderTitle = ""
        isSelectionModeActive = false
        selectedIDs.removeAll()
        fetchAudiobooks()
    }

    func deleteFolder(_ folder: Folder) {
        modelContext.delete(folder)
        saveContext(errorContext: "delete folder")
        fetchAudiobooks()
    }

    func deleteFolderAndBooks(_ folder: Folder) {
        let booksToDelete = folder.audiobooks
        for book in booksToDelete {
            try? libraryManager.deleteAudiobookFile(at: book.fileURL)
            modelContext.delete(book)
        }
        modelContext.delete(folder)
        saveContext(errorContext: "delete folder and books")
        fetchAudiobooks()
    }

    func removeFromFolder(_ audiobook: Audiobook) {
        audiobook.folder = nil
        saveContext(errorContext: "remove from folder")
        fetchAudiobooks()
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

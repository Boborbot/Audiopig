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

    // MARK: - Selection State

    private(set) var isSelectionModeActive: Bool = false
    private(set) var selectedIDs: Set<UUID> = []

    // MARK: - Sheet / Modal State

    var isMergeSheetPresented: Bool = false
    var pendingMergeTitle: String = ""
    var isFileImporterPresented: Bool = false

    // MARK: - Player Sub-ViewModel

    let playerViewModel: PlayerViewModel

    // MARK: - Computed

    var canMergeSelected: Bool { selectedIDs.count >= 2 }
    var selectedCount: Int { selectedIDs.count }

    func isSelected(_ audiobook: Audiobook) -> Bool {
        selectedIDs.contains(audiobook.id)
    }

    private var selectedAudiobooks: [Audiobook] {
        audiobooks.filter { selectedIDs.contains($0.id) }
    }

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let libraryManager: any LibraryManagerProtocol

    // MARK: - Init

    init(
        modelContext: ModelContext,
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol
    ) {
        self.modelContext = modelContext
        self.libraryManager = libraryManager
        self.playerViewModel = PlayerViewModel(audioEngine: audioEngine, modelContext: modelContext)
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
    }

    func toggleSelection(_ audiobook: Audiobook) {
        if selectedIDs.contains(audiobook.id) {
            selectedIDs.remove(audiobook.id)
        } else {
            selectedIDs.insert(audiobook.id)
        }
    }

    // MARK: - Delete

    func delete(_ audiobook: Audiobook) {
        try? libraryManager.deleteAudiobookFile(at: audiobook.fileURL)
        modelContext.delete(audiobook)
        saveContext(errorContext: "delete audiobook")
        fetchAudiobooks()
    }

    func delete(at indexSet: IndexSet) {
        indexSet.compactMap { audiobooks[safe: $0] }.forEach { delete($0) }
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

    // MARK: - Error Handling

    func clearError() { errorMessage = nil }

    // MARK: - Private

    private func saveContext(errorContext: String) {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to \(errorContext)."
        }
    }
}

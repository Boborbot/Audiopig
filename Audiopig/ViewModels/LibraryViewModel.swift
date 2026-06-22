//
//  LibraryViewModel.swift
//  Audiopig
//

import Observation
import SwiftData
import Foundation
import UIKit

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
    var librarySortOrder: LibrarySortOrder
    var libraryBookFilter: LibraryBookFilter
    var librarySortDirection: LibrarySortDirection

    var filteredAudiobooks: [Audiobook] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matching: [Audiobook]
        if trimmed.isEmpty {
            matching = audiobooks
        } else {
            let query = trimmed.lowercased()
            matching = audiobooks.filter { book in
                book.title.lowercased().contains(query)
                    || book.author.lowercased().contains(query)
                    || book.fileURL.deletingPathExtension().lastPathComponent.lowercased().contains(query)
            }
        }
        return sortedAudiobooks(matching)
    }

    /// Items shown in the root library list.
    /// Normal mode: folders + root-level books (no folder) ordered by `librarySortOrder`.
    /// Search mode: all matching books regardless of folder, no folder rows.
    var libraryItems: [LibraryItem] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if isSearchActive && !trimmed.isEmpty {
            return filteredAudiobooks.map { .audiobook($0) }
        }

        let rootBooks = sortedAudiobooks(audiobooks.filter { $0.folder == nil })
        let bookItems = rootBooks.map { LibraryItem.audiobook($0) }

        guard libraryBookFilter == .all else {
            return bookItems
        }

        let sortedFolders = folders.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
        let folderItems = sortedFolders.map { LibraryItem.folder($0) }

        switch librarySortOrder {
        case .title:
            let combined = (bookItems + folderItems).sorted {
                $0.sortTitle.localizedCaseInsensitiveCompare($1.sortTitle) == .orderedAscending
            }
            return librarySortDirection == .descending ? combined.reversed() : combined
        default:
            return bookItems + folderItems
        }
    }

    func sortedAudiobooks(_ books: [Audiobook]) -> [Audiobook] {
        let filtered = books.filter { libraryBookFilter.includes(lastPlayedAt: $0.lastPlayedAt) }
        let candidates = filtered.map { $0.librarySortCandidate() }
        let sortedIDs = LibrarySorter.sorted(
            candidates,
            by: librarySortOrder,
            direction: librarySortDirection
        ).map(\.id)
        let bookByID = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
        return sortedIDs.compactMap { bookByID[$0] }
    }

    func sortedAudiobooks(in folder: Folder) -> [Audiobook] {
        sortedAudiobooks(folder.audiobooks)
    }

    func setLibrarySortOrder(_ order: LibrarySortOrder) {
        librarySortOrder = order
        appSettings.librarySortOrder = order
    }

    func cycleLibraryBookFilter() {
        libraryBookFilter = libraryBookFilter.next
        appSettings.libraryBookFilter = libraryBookFilter
    }

    func toggleLibrarySortDirection() {
        librarySortDirection = librarySortDirection.toggled
        appSettings.librarySortDirection = librarySortDirection
    }

    // MARK: - Selection State

    private(set) var isSelectionModeActive: Bool = false
    private(set) var selectedIDs: Set<UUID> = []

    // MARK: - Sheet / Modal State

    var isMergeSheetPresented: Bool = false
    var pendingMergeTitle: String = ""
    var isFolderSheetPresented: Bool = false
    var pendingFolderTitle: String = ""
    var folderPendingDelete: Folder? = nil
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

    /// Set when finishing a book unlocks a new app icon.
    /// Drives the `IconUnlockOverlay` in `LibraryView`.
    var newlyUnlockedIcon: AppIconUnlock?

    private var pendingIconUnlocks: [AppIconUnlock] = []
    private var processedNaturalFinishIDs: Set<UUID> = []

    /// When `autoDeleteOnFinish` is on, the book is held here until the celebration
    /// completes, then the user is asked whether to delete it.
    private var pendingAutoDeleteBook: Audiobook?

    /// Shown after the finish celebration when auto-delete is enabled.
    var isAutoDeleteConfirmationPresented: Bool = false

    var pendingAutoDeleteBookTitle: String {
        pendingAutoDeleteBook?.title ?? "this audiobook"
    }

    // MARK: - Pending Edit

    var bookPendingEdit: Audiobook?

    // MARK: - Pending Delete

    private var pendingSwipeDeleteIndexSet: IndexSet?
    private var pendingSwipeDeleteBook: Audiobook?

    // MARK: - Watch Transfer UI

    private(set) var watchTransferStateRevision: UInt64 = 0

    // MARK: - Dependencies

    private let modelContext: ModelContext
    private let libraryManager: any LibraryManagerProtocol
    private let appSettings: AppSettings
    let appIconManager: AppIconManager
    private let watchBridge: (any WatchConnectivityBridgeProtocol)?
    private let watchTransferService: (any WatchTransferServiceProtocol)?
    private let volumeController: SystemVolumeController
    private let monetization: any MonetizationServiceProtocol

    /// Called after listening stats change (book finish, merge cleanup, etc.).
    @ObservationIgnored
    var onReadingStatsChanged: (() -> Void)?

    // MARK: - Init

    init(
        modelContext: ModelContext,
        libraryManager: any LibraryManagerProtocol,
        audioEngine: any AudioEngineProtocol,
        appSettings: AppSettings,
        appIconManager: AppIconManager,
        watchBridge: (any WatchConnectivityBridgeProtocol)? = nil,
        watchTransferService: (any WatchTransferServiceProtocol)? = nil,
        volumeController: SystemVolumeController,
        monetization: any MonetizationServiceProtocol
    ) {
        self.modelContext = modelContext
        self.libraryManager = libraryManager
        self.appSettings = appSettings
        self.appIconManager = appIconManager
        self.watchBridge = watchBridge
        self.watchTransferService = watchTransferService
        self.volumeController = volumeController
        self.monetization = monetization
        self.librarySortOrder = appSettings.librarySortOrder
        self.libraryBookFilter = appSettings.libraryBookFilter
        self.librarySortDirection = appSettings.librarySortDirection
        self.playerViewModel = PlayerViewModel(
            audioEngine: audioEngine,
            modelContext: modelContext,
            appSettings: appSettings,
            watchBridge: watchBridge,
            monetization: monetization
        )
        self.playerViewModel.onNaturalFinish = { [weak self] audiobook in
            self?.handleNaturalFinish(audiobook)
        }
        self.playerViewModel.onPlaybackPositionSaved = { [weak self] in
            self?.syncWatchRecentBooks()
        }
        self.playerViewModel.onAudiobookLoaded = { [weak self] in
            self?.syncWatchRecentBooks()
        }
        watchBridge?.commandHandler = { [weak self] command in
            await self?.handleWatchCommand(command) ?? .failure("Library unavailable.")
        }
        watchTransferService?.onStateChanged = { [weak self] in
            self?.watchTransferStateRevision &+= 1
        }
        watchBridge?.reachabilityHandler = { [weak self] isReachable in
            guard let self, isReachable else { return }
            self.playerViewModel.syncWatchState(includeArtwork: self.shouldIncludeWatchArtwork)
            self.syncWatchSettings()
            self.syncWatchRecentBooks()
            if WatchFeatures.localPlaybackEnabled {
                Task { await self.syncWatchLocalBooks() }
            }
        }
        fetchAudiobooks(repairFileReferences: false)
    }

    // MARK: - Startup

    /// Repairs library paths, syncs companion surfaces, and refreshes entitlements after the
    /// root UI is on screen so launch is not blocked by file I/O or cover-art decoding.
    func performDeferredStartup() async {
        try? libraryManager.repairAudiobookFileReferences(in: modelContext)
        fetchAudiobooks(repairFileReferences: false)
        syncWatchSettings()
        syncWatchRecentBooks()
        if WatchFeatures.localPlaybackEnabled {
            await syncWatchLocalBooks()
        }
        await monetization.refreshEntitlements()
        syncWatchSettings()
    }

    // MARK: - Fetch

    func fetchAudiobooks(repairFileReferences: Bool = true) {
        if repairFileReferences {
            try? libraryManager.repairAudiobookFileReferences(in: modelContext)
        }

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
            try? libraryManager.repairAudiobookFileReferences(in: modelContext)
            await playerViewModel.loadAudiobook(audiobook, autoPlay: true)
        }
    }

    @discardableResult
    func playAudiobook(id: UUID) -> Bool {
        guard let audiobook = resolveAudiobook(id: id) else { return false }
        openPlayer(for: audiobook)
        return true
    }

    /// Starts or resumes playback from a lock screen widget / control, then presents the player.
    func playAudiobookFromWidget(id: UUID) async throws {
        guard let audiobook = resolveAudiobook(id: id) else {
            throw WidgetPlaybackError.bookNotFound
        }
        try? libraryManager.repairAudiobookFileReferences(in: modelContext)

        if playerViewModel.audiobook?.id == id {
            switch playerViewModel.playbackState {
            case .playing:
                return
            case .paused, .finished, .idle:
                playerViewModel.play()
                return
            case .loading:
                return
            case .failed:
                break
            }
        }

        await playerViewModel.loadAudiobook(audiobook, autoPlay: true)
    }

    func playLastAudiobookFromWidget() async throws {
        let snapshot = WidgetListeningSnapshot.load()
        guard let idString = snapshot.lastPlayedAudiobookID,
              let bookID = UUID(uuidString: idString) else {
            throw WidgetPlaybackError.noLastPlayedBook
        }
        try await playAudiobookFromWidget(id: bookID)
    }

    // MARK: - Watch Commands

    func handleWatchCommand(_ command: WatchCommand) async -> WatchCommandResult {
        switch command {
        case .requestRecentBooks:
            let payload = WatchRecentBooksPayload(books: recentBooksForWatch(limit: 10))
            watchBridge?.publishRecentBooks(payload)
            return .ok(recentBooks: payload)

        case .requestSnapshot:
            let includeArtwork = shouldIncludeWatchArtwork
            playerViewModel.syncWatchState(includeArtwork: includeArtwork)
            return .ok(
                snapshot: playerViewModel.watchSnapshotForReply(includeArtwork: includeArtwork)
            )

        case .loadBook(let bookID, let autoPlay):
            guard let audiobook = audiobook(withID: bookID) else {
                return .failure("Book not found.")
            }
            await playerViewModel.loadAudiobook(audiobook, autoPlay: autoPlay)
            return .ok(snapshot: playerViewModel.watchSnapshotForReply(includeArtwork: true))

        case .togglePlayPause:
            playerViewModel.togglePlayPause()
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .play:
            playerViewModel.play()
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .pause:
            playerViewModel.pause()
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .skipForward:
            playerViewModel.skipForward()
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .skipBackward:
            playerViewModel.skipBackward()
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .setSpeed(let speed):
            playerViewModel.setSpeed(speed)
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .setVolume(let volume):
            let normalized = WatchVolumeRange.normalized(volume)
            volumeController.setVolume(normalized)
            playerViewModel.syncWatchState()
            return .ok(
                snapshot: playerViewModel.watchSnapshotForReply(systemVolumeOverride: normalized)
            )

        case .seekToChapterIndex(let index):
            guard playerViewModel.chapters.indices.contains(index) else {
                return .failure("Chapter not found.")
            }
            playerViewModel.seekToChapter(playerViewModel.chapters[index])
            playerViewModel.syncWatchState()
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .seekToChapter(let id):
            guard let chapter = playerViewModel.chapters.first(where: { $0.id == id }) else {
                return .failure("Chapter not found.")
            }
            playerViewModel.seekToChapter(chapter)
            playerViewModel.syncWatchState()
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .setArtworkSkipGesturesEnabled(let enabled):
            appSettings.watchArtworkSkipGesturesEnabled = enabled
            syncWatchSettings()
            return .ok()

        case .setWatchArtworkViewMode(let mode):
            guard mode == .off || monetization.hasAccess(to: .watchArtworkView) else {
                return .failure("Audiopig Plus required on iPhone.")
            }
            appSettings.watchArtworkViewMode = mode
            syncWatchSettings()
            if mode != .off {
                playerViewModel.syncWatchState(includeArtwork: true)
                return .ok(snapshot: playerViewModel.watchSnapshotForReply(includeArtwork: true))
            }
            return .ok()

        case .analyzeLulls:
            guard monetization.hasAccess(to: .paragraphBreaks) else {
                return .failure("Audiopig Plus required on iPhone.")
            }
            guard playerViewModel.audiobook != nil else {
                return .failure("No book loaded on iPhone.")
            }
            let lull = await playerViewModel.analyzeLullsForWatch()
            return .ok(
                snapshot: playerViewModel.watchSnapshotForReply(),
                lullResult: lull
            )

        case .seekToLull(let endTime):
            playerViewModel.seekToLullEndTime(endTime)
            return .ok(snapshot: playerViewModel.watchSnapshotForReply())

        case .syncLocalPlaybackPosition(let bookID, let time):
            if let audiobook = audiobook(withID: bookID) {
                audiobook.currentPlaybackTime = time
                try? modelContext.save()
            }
            return .ok()

        case .acknowledgeLocalBooks(let payload):
            guard WatchFeatures.localPlaybackEnabled else { return .ok() }
            watchBridge?.publishLocalBooks(payload)
            watchTransferService?.handleLocalBooksAcknowledgement(payload)
            return .ok()

        case .reportTransferIngestFailed(let bookID, let errorMessage):
            guard WatchFeatures.localPlaybackEnabled else { return .ok() }
            watchTransferService?.handleTransferFailure(bookID: bookID, errorMessage: errorMessage)
            return .ok()

        case .requestLocalBooks, .loadLocalBook, .deleteLocalBook:
            return .failure("Command is handled on Apple Watch.")
        }
    }

    // MARK: - Watch Transfer

    func sendToWatch(_ audiobook: Audiobook) async {
        await watchTransferService?.transfer(audiobook: audiobook)
    }

    func sendSelectedToWatch() async {
        await watchTransferService?.transfer(audiobooks: selectedAudiobooks)
    }

    func removeFromWatch(_ audiobook: Audiobook) async {
        await watchTransferService?.removeFromWatch(bookID: audiobook.id)
    }

    func cancelWatchTransfer(_ audiobook: Audiobook) {
        watchTransferService?.cancelTransfer(bookID: audiobook.id)
    }

    func watchStatus(for audiobook: Audiobook) -> WatchBookTransferStatus {
        _ = watchTransferStateRevision
        guard let service = watchTransferService else { return .unavailable }
        if service.isOnWatch(bookID: audiobook.id) { return .onWatch }
        if let progress = service.transferProgress(for: audiobook.id), service.isTransferring(bookID: audiobook.id) {
            return .transferring(progress: progress)
        }
        if let message = service.transferFailureMessage(for: audiobook.id) {
            return .failed(message)
        }
        return .notOnWatch
    }

    var watchLocalBooks: WatchLocalBooksPayload? {
        _ = watchTransferStateRevision
        return watchTransferService?.localBooks
    }

    func syncWatchLocalBooks() async {
        guard WatchFeatures.localPlaybackEnabled else { return }
        await watchTransferService?.refreshWatchLibraryState()
    }

    func syncWatchSettings() {
        watchBridge?.publishSettings(
            appSettings.watchSettingsSnapshot(
                hasParagraphBreaksAccess: monetization.hasAccess(to: .paragraphBreaks),
                hasWatchArtworkViewAccess: monetization.hasAccess(to: .watchArtworkView)
            )
        )
    }

    func syncWatchRecentBooks() {
        let books = recentBooksForWatch(limit: 10)
        watchBridge?.publishRecentBooks(WatchRecentBooksPayload(books: books))
        syncWidgetRecentBooks()
    }

    func syncWidgetRecentBooks() {
        WidgetSnapshotWriter.syncRecentBooks(books: recentBooksForWatch(limit: 5))
    }

    func recentBooksForWatch(limit: Int) -> [WatchBookSummary] {
        var descriptor = FetchDescriptor<Audiobook>(
            predicate: #Predicate { $0.lastPlayedAt != nil },
            sortBy: [SortDescriptor(\.lastPlayedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        let books = (try? modelContext.fetch(descriptor)) ?? []
        return books.map { book in
            WatchSnapshotBuilder.makeBookSummary(
                from: book,
                coverImage: CoverArtCache.shared.image(for: book)
            )
        }
    }

    private func audiobook(withID id: UUID) -> Audiobook? {
        audiobooks.first { $0.id == id }
    }

    private var shouldIncludeWatchArtwork: Bool {
        appSettings.watchArtworkViewMode != .off
            && monetization.hasAccess(to: .watchArtworkView)
    }

    private func resolveAudiobook(id: UUID) -> Audiobook? {
        if let cached = audiobook(withID: id) { return cached }
        var descriptor = FetchDescriptor<Audiobook>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
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

        guard !hasFinishedRecord(for: audiobook.id) else {
            saveContext(errorContext: "mark finished")
            return
        }

        processBookFinish(for: audiobook, wasManuallyMarked: true)
    }

    /// Called when playback reaches the natural end of a book.
    func handleNaturalFinish(_ audiobook: Audiobook) {
        guard !audiobook.isManuallyFinished else { return }
        guard audiobook.isFinished else { return }
        guard !processedNaturalFinishIDs.contains(audiobook.id) else { return }

        processedNaturalFinishIDs.insert(audiobook.id)

        guard !hasFinishedRecord(for: audiobook.id) else { return }

        processBookFinish(for: audiobook, wasManuallyMarked: false)
    }

    private func processBookFinish(for audiobook: Audiobook, wasManuallyMarked: Bool) {
        let finishEvent = BookFinishEvent(
            audiobookID: audiobook.id,
            title: audiobook.title,
            author: audiobook.author,
            totalSeconds: audiobook.duration,
            listenedSeconds: audiobook.accumulatedListeningSeconds,
            chapterCount: audiobook.chapters.count,
            finishedAt: Date(),
            wasManuallyMarked: wasManuallyMarked
        )

        if appSettings.trackReadingStats, !hasFinishedRecord(for: audiobook.id) {
            let record = FinishedRecord(
                audiobookID: finishEvent.audiobookID,
                title: finishEvent.title,
                author: finishEvent.author,
                totalSeconds: finishEvent.totalSeconds,
                listenedSeconds: finishEvent.listenedSeconds,
                finishedAt: finishEvent.finishedAt,
                chapterCount: finishEvent.chapterCount,
                wasManuallyMarked: wasManuallyMarked
            )
            modelContext.insert(record)
        }

        saveContext(errorContext: "mark finished")
        enqueueIconUnlocks(finishEvent: finishEvent)

        if appSettings.autoExportOnFinish {
            _ = try? BookmarkExportService.export(audiobook)
        }

        if appSettings.autoDeleteOnFinish {
            pendingAutoDeleteBook = audiobook
        }

        celebratedBook = audiobook
        onReadingStatsChanged?()
    }

    /// Computes total finished-book listening time and asks `AppIconManager`
    /// whether any new icons are now unlocked.
    private func enqueueIconUnlocks(finishEvent: BookFinishEvent) {
        let records    = (try? modelContext.fetch(FetchDescriptor<FinishedRecord>())) ?? []
        let allBooks   = (try? modelContext.fetch(FetchDescriptor<Audiobook>()))      ?? []

        let totals = ListeningStatsAggregator.compute(
            books: allBooks.map {
                ListeningStatsBookInput(
                    id: $0.id,
                    accumulatedListeningSeconds: $0.accumulatedListeningSeconds,
                    isFinished: $0.isFinished
                )
            },
            records: records.map {
                ListeningStatsFinishRecordInput(
                    audiobookID: $0.audiobookID,
                    listenedSeconds: $0.listenedSeconds,
                    finishedAt: $0.finishedAt
                )
            }
        )

        let unlocks = appIconManager.checkForNewUnlocks(
            totalFinishedSeconds: totals.finishedListenedSeconds,
            finishEvent: finishEvent
        )

        guard !unlocks.isEmpty else { return }

        pendingIconUnlocks.append(contentsOf: unlocks)
        if newlyUnlockedIcon == nil {
            newlyUnlockedIcon = pendingIconUnlocks.removeFirst()
        }
    }

    /// Advances the icon-unlock overlay queue, or clears it when empty.
    func dismissIconUnlock() {
        if pendingIconUnlocks.isEmpty {
            newlyUnlockedIcon = nil
        } else {
            newlyUnlockedIcon = pendingIconUnlocks.removeFirst()
        }
    }

    /// Unmarks a book so it is no longer manually finished and removes its finished records.
    func markUnfinished(_ audiobook: Audiobook) {
        audiobook.isManuallyFinished = false
        removeFinishedRecords(for: audiobook.id)
        saveContext(errorContext: "mark unfinished")
        onReadingStatsChanged?()
    }

    /// Clears the celebration overlay; prompts to delete when auto-delete is pending.
    func dismissCelebration() {
        celebratedBook = nil
        if pendingAutoDeleteBook != nil {
            isAutoDeleteConfirmationPresented = true
        }
    }

    func confirmAutoDelete() {
        guard let book = pendingAutoDeleteBook else { return }
        pendingAutoDeleteBook = nil
        isAutoDeleteConfirmationPresented = false
        delete(book)
    }

    func cancelAutoDelete() {
        pendingAutoDeleteBook = nil
        isAutoDeleteConfirmationPresented = false
    }

    private func removeFinishedRecords(for audiobookID: UUID) {
        let id = audiobookID
        let descriptor = FetchDescriptor<FinishedRecord>(
            predicate: #Predicate { $0.audiobookID == id }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        records.forEach { modelContext.delete($0) }
    }

    private func hasFinishedRecord(for audiobookID: UUID) -> Bool {
        let id = audiobookID
        let descriptor = FetchDescriptor<FinishedRecord>(
            predicate: #Predicate { $0.audiobookID == id }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return !records.isEmpty
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

    // MARK: - Edit

    func requestEdit(_ audiobook: Audiobook) {
        bookPendingEdit = audiobook
    }

    func finishEdit() {
        bookPendingEdit = nil
        fetchAudiobooks()
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
        if appSettings.autoExportOnDelete {
            _ = try? BookmarkExportService.export(audiobook)
        }
        _ = try? libraryManager.deleteAudiobookFile(at: audiobook.fileURL)
        modelContext.delete(audiobook)
        saveContext(errorContext: "delete audiobook")
        fetchAudiobooks()
        syncWatchRecentBooks()
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

    /// Opens the combine sheet, snapshotting the current selection into mergeOrder
    /// so the user can drag to set the desired playback order before confirming.
    func presentMergeSheet() {
        mergeOrder = selectedAudiobooks
        syncSuggestedMergeTitle()
        isMergeSheetPresented = true
    }

    func moveMergeBook(from source: IndexSet, to destination: Int) {
        let previousFirstTitle = mergeOrder.first?.title
        guard let sourceIndex = source.first else { return }
        let item = mergeOrder.remove(at: sourceIndex)
        let insertAt = destination > sourceIndex ? destination - 1 : destination
        mergeOrder.insert(item, at: min(insertAt, mergeOrder.count))

        let trimmedTitle = pendingMergeTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedTitle.isEmpty || trimmedTitle == previousFirstTitle {
            syncSuggestedMergeTitle()
        }
    }

    private func syncSuggestedMergeTitle() {
        pendingMergeTitle = mergeOrder.first?.title ?? ""
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
            let absorbedIDs = mergeOrder.dropFirst().map(\.id)
            _ = try libraryManager.merge(
                audiobooks: mergeOrder,
                intoTitle: title,
                in: modelContext
            )
            absorbedIDs.forEach { removeFinishedRecords(for: $0) }
            saveContext(errorContext: "merge audiobooks")
            isSelectionModeActive = false
            selectedIDs.removeAll()
            fetchAudiobooks()
            onReadingStatsChanged?()
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
            if appSettings.autoExportOnDelete {
                _ = try? BookmarkExportService.export(book)
            }
            _ = try? libraryManager.deleteAudiobookFile(at: book.fileURL)
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

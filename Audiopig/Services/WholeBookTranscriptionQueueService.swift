//
//  WholeBookTranscriptionQueueService.swift
//  Audiopig
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class WholeBookTranscriptionQueueService: WholeBookTranscriptionQueueServiceProtocol {

    private(set) var revision: UInt64 = 0

    var hasQueueUI: Bool { !sortedEntries().isEmpty }
    var hasActiveJob: Bool { workerTask != nil }
    var queueCount: Int { sortedEntries().count }

    private let modelContext: ModelContext
    private let subtitleStore: any SubtitleStoreProtocol
    private let transcriptionService: any SubtitleTranscriptionServiceProtocol
    private let monetization: any MonetizationServiceProtocol
    private let localeProvider: () -> String

    private var workerTask: Task<Void, Never>?
    private var orchestrator: SubtitleGenerationOrchestrator?
    private var activeAudiobookID: UUID?
    private var workerGeneration: UInt64 = 0

    private var activeProgress = ActiveProgress()

    /// Called on the main actor after queue state changes (progress, enqueue, completion).
    var onRevisionChanged: (() -> Void)?

    private struct ActiveProgress {
        var isPreparing = false
        var completedWindows = 0
        var totalWindows = 0
        var message: String?
    }

    init(
        modelContext: ModelContext,
        subtitleStore: any SubtitleStoreProtocol,
        transcriptionService: any SubtitleTranscriptionServiceProtocol,
        monetization: any MonetizationServiceProtocol,
        localeProvider: @escaping () -> String
    ) {
        self.modelContext = modelContext
        self.subtitleStore = subtitleStore
        self.transcriptionService = transcriptionService
        self.monetization = monetization
        self.localeProvider = localeProvider
    }

    func allSnapshots() -> [WholeBookQueueItemSnapshot] {
        let entries = sortedEntries()
        return entries.enumerated().compactMap { index, entry in
            snapshot(for: entry, position: index + 1)
        }
    }

    func snapshot(for audiobookID: UUID?) -> WholeBookQueueItemSnapshot? {
        guard let audiobookID else { return nil }
        let entries = sortedEntries()
        guard let index = entries.firstIndex(where: { $0.audiobook?.id == audiobookID }) else {
            return nil
        }
        return snapshot(for: entries[index], position: index + 1)
    }

    func queuePosition(for audiobookID: UUID) -> Int? {
        let entries = sortedEntries()
        guard let index = entries.firstIndex(where: { $0.audiobook?.id == audiobookID }) else {
            return nil
        }
        return index + 1
    }

    @discardableResult
    func enqueue(audiobookID: UUID, fromPlayhead: TimeInterval?) -> WholeBookEnqueueResult {
        guard transcriptionService.isSupported else { return .unsupported }
        guard monetization.hasAccess(to: .subtitles) else { return .paywallRequired }
        guard let audiobook = fetchAudiobook(id: audiobookID) else { return .alreadyComplete }

        let segments = (try? subtitleStore.sortedSegments(for: audiobookID)) ?? []
        let uncovered = SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: audiobook.duration,
            segments: segments,
            fromPlayhead: fromPlayhead
        )
        guard !uncovered.isEmpty else {
            if fromPlayhead == nil {
                markBookComplete(audiobook)
            }
            return .alreadyComplete
        }

        if sortedEntries().contains(where: { $0.audiobook?.id == audiobookID }) {
            return .alreadyInQueue
        }

        let nextIndex = (sortedEntries().map(\.orderIndex).max() ?? -1) + 1
        let entry = WholeBookTranscriptionQueueEntry(
            orderIndex: nextIndex,
            audiobook: audiobook,
            status: .queued,
            fromPlayhead: fromPlayhead
        )
        if let fromPlayhead {
            audiobook.subtitleGenerationFromPlayhead = fromPlayhead
        }
        modelContext.insert(entry)
        try? modelContext.save()
        bumpRevision()
        startWorkerIfNeeded()
        return .enqueued
    }

    func cancel(audiobookID: UUID) {
        guard let entry = entry(for: audiobookID) else { return }
        let isActive = entry.audiobook?.id == activeAudiobookID

        if isActive {
            workerGeneration &+= 1
            workerTask?.cancel()
            workerTask = nil
            let orch = orchestrator
            orchestrator = nil
            activeAudiobookID = nil
            if let orch {
                Task { await orch.cancel() }
            }
        }

        if let audiobook = entry.audiobook {
            let cues = (try? subtitleStore.sortedCues(for: audiobook.id)) ?? []
            audiobook.subtitleGenerationStatus = cues.isEmpty ? .notGenerated : .partial
            audiobook.subtitleGenerationScope = nil
            audiobook.subtitleGenerationFromPlayhead = nil
        }

        modelContext.delete(entry)
        try? modelContext.save()
        bumpRevision()

        if isActive {
            processNext()
        }
    }

    func pause(audiobookID: UUID) {
        guard activeAudiobookID == audiobookID,
              let entry = entry(for: audiobookID),
              entry.status == .running
        else { return }

        entry.status = .paused
        if let audiobook = entry.audiobook {
            audiobook.subtitleGenerationStatus = .paused
        }
        try? modelContext.save()
        Task { await orchestrator?.pause() }
        bumpRevision()
    }

    func resume(audiobookID: UUID) {
        guard let entry = entry(for: audiobookID) else { return }

        if entry.status == .failed {
            entry.status = .queued
            entry.failureMessage = nil
            if let audiobook = entry.audiobook {
                audiobook.subtitleGenerationStatus = .partial
            }
            try? modelContext.save()
            bumpRevision()
            startWorkerIfNeeded()
            return
        }

        guard entry.status == .paused else { return }

        if activeAudiobookID == audiobookID {
            entry.status = .running
            if let audiobook = entry.audiobook {
                audiobook.subtitleGenerationStatus = .inProgress
            }
            try? modelContext.save()
            Task { await orchestrator?.resume() }
            bumpRevision()
            return
        }

        entry.status = .queued
        try? modelContext.save()
        bumpRevision()
        startWorkerIfNeeded()
    }

    func moveEntry(from source: IndexSet, to destination: Int) {
        var entries = sortedEntries()
        guard let sourceIndex = source.first else { return }
        guard entries.indices.contains(sourceIndex) else { return }

        if entries[sourceIndex].status == .running { return }
        let runningPositions = Dictionary(
            uniqueKeysWithValues: entries.enumerated().compactMap { index, entry in
                entry.status == .running ? (entry.id, index) : nil
            }
        )

        let item = entries.remove(at: sourceIndex)
        let insertAt = destination > sourceIndex ? destination - 1 : destination
        entries.insert(item, at: min(insertAt, entries.count))

        let preservesRunningPositions = runningPositions.allSatisfy { id, originalIndex in
            entries.firstIndex(where: { $0.id == id }) == originalIndex
        }
        guard preservesRunningPositions else { return }

        for (offset, entry) in entries.enumerated() {
            entry.orderIndex = offset
        }
        try? modelContext.save()
        bumpRevision()
    }

    func restoreOnLaunch() {
        reconcileOrphanedInProgressBooks()
        bumpRevision()
        startWorkerIfNeeded()
    }

    // MARK: - Worker

    private func startWorkerIfNeeded() {
        guard workerTask == nil else { return }
        guard let next = nextRunnableEntry() else { return }

        workerGeneration &+= 1
        let generation = workerGeneration
        workerTask = Task { [weak self] in
            await self?.runBook(entry: next, generation: generation)
        }
    }

    private func processNext() {
        workerTask = nil
        orchestrator = nil
        activeAudiobookID = nil
        activeProgress = ActiveProgress()
        bumpRevision()
        startWorkerIfNeeded()
    }

    private func runBook(entry: WholeBookTranscriptionQueueEntry, generation: UInt64) async {
        guard generation == workerGeneration else { return }
        guard let audiobook = entry.audiobook else {
            modelContext.delete(entry)
            try? modelContext.save()
            processNext()
            return
        }

        activeAudiobookID = audiobook.id
        entry.status = .running
        activeProgress.isPreparing = true
        activeProgress.message = "Preparing transcription…"
        bumpRevision()

        let fromPlayhead = entry.fromPlayhead
        let segments = (try? subtitleStore.sortedSegments(for: audiobook.id)) ?? []
        let uncovered = SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: audiobook.duration,
            segments: segments,
            fromPlayhead: fromPlayhead
        )

        if uncovered.isEmpty {
            finishEntrySuccess(entry: entry, audiobook: audiobook, bookDuration: audiobook.duration)
            return
        }

        let scopedWindows: [SubtitleTimeWindow]
        if let fromPlayhead {
            scopedWindows = SubtitleWindowPlanner.windowsFromCurrentSection(
                playhead: fromPlayhead,
                bookDuration: audiobook.duration
            )
        } else {
            scopedWindows = SubtitleWindowPlanner.wholeBookWindows(bookDuration: audiobook.duration)
        }
        activeProgress.totalWindows = scopedWindows.count
        activeProgress.completedWindows = scopedWindows.count - uncovered.count

        let scope: SubtitleGenerationScope = fromPlayhead == nil ? .wholeBook : .fromCurrentPosition
        audiobook.subtitleGenerationScope = scope
        audiobook.subtitleGenerationFromPlayhead = fromPlayhead
        audiobook.subtitleGenerationStatus = .inProgress
        let locale = localeProvider()
        audiobook.subtitleLocaleIdentifier = locale
        try? modelContext.save()

        let resolvedChapters = audiobook.chapters.sorted { $0.orderIndex < $1.orderIndex }.map { ResolvedChapter(from: $0) }
        let orch = SubtitleGenerationOrchestrator(transcriptionService: transcriptionService)
        orchestrator = orch
        activeProgress.isPreparing = false
        bumpRevision()

        let bookID = audiobook.id
        let bookDuration = audiobook.duration

        do {
            try await orch.generate(
                scope: scope,
                playhead: fromPlayhead ?? 0,
                bookDuration: bookDuration,
                chapters: resolvedChapters,
                existingSegments: segments,
                localeIdentifier: locale,
                onWindowComplete: { [weak self] window, cues in
                    await self?.persistWindow(
                        window: window,
                        cues: cues,
                        bookID: bookID,
                        generation: generation
                    )
                },
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        guard let self, generation == self.workerGeneration else { return }
                        self.activeProgress.isPreparing = false
                        self.activeProgress.completedWindows = progress.completedWindows
                        if let total = progress.totalWindows {
                            self.activeProgress.totalWindows = total
                        }
                        self.activeProgress.message = progress.message
                        self.bumpRevision()
                    }
                }
            )
            guard generation == workerGeneration else { return }
            finishEntrySuccess(entry: entry, audiobook: audiobook, bookDuration: bookDuration)
        } catch is CancellationError {
            guard generation == workerGeneration else { return }
            // Cancel path handled explicitly via cancel(); task cancellation during teardown.
            processNext()
        } catch {
            guard generation == workerGeneration else { return }
            finishEntryFailure(entry: entry, audiobook: audiobook, error: error)
        }
    }

    private func finishEntrySuccess(
        entry: WholeBookTranscriptionQueueEntry,
        audiobook: Audiobook,
        bookDuration: TimeInterval
    ) {
        let segments = (try? subtitleStore.sortedSegments(for: audiobook.id)) ?? []
        let uncovered = SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: bookDuration,
            segments: segments
        )

        if uncovered.isEmpty {
            audiobook.subtitleGenerationStatus = .complete
            audiobook.subtitleLastCoveredEndTime = bookDuration
        } else {
            let cues = (try? subtitleStore.sortedCues(for: audiobook.id)) ?? []
            audiobook.subtitleGenerationStatus = cues.isEmpty && segments.isEmpty ? .failed : .partial
        }
        audiobook.subtitleGenerationScope = nil
        audiobook.subtitleGenerationFromPlayhead = nil

        modelContext.delete(entry)
        try? modelContext.save()
        processNext()
    }

    private func finishEntryFailure(
        entry: WholeBookTranscriptionQueueEntry,
        audiobook: Audiobook,
        error: Error
    ) {
        entry.status = .failed
        entry.failureMessage = error.localizedDescription
        let cues = (try? subtitleStore.sortedCues(for: audiobook.id)) ?? []
        audiobook.subtitleGenerationStatus = cues.isEmpty ? .failed : .partial
        audiobook.subtitleGenerationScope = nil
        audiobook.subtitleGenerationFromPlayhead = nil
        try? modelContext.save()
        workerTask = nil
        orchestrator = nil
        activeAudiobookID = nil
        activeProgress = ActiveProgress()
        bumpRevision()
    }

    @MainActor
    private func persistWindow(
        window: SubtitleTimeWindow,
        cues: [SubtitleCueTiming],
        bookID: UUID,
        generation: UInt64
    ) async {
        guard generation == workerGeneration else { return }
        guard let audiobook = fetchAudiobook(id: bookID) else { return }
        try? subtitleStore.insertSegment(window: window, audiobook: audiobook)
        try? subtitleStore.insertCues(cues, audiobook: audiobook)
        audiobook.subtitleLastCoveredEndTime = max(audiobook.subtitleLastCoveredEndTime, window.globalEnd)
        audiobook.subtitleGenerationStatus = .partial
        try? modelContext.save()
        bumpRevision()
    }

    // MARK: - Helpers

    private func nextRunnableEntry() -> WholeBookTranscriptionQueueEntry? {
        sortedEntries().first { entry in
            switch entry.status {
            case .queued, .running:
                return true
            case .paused, .failed:
                return false
            }
        }
    }

    private func sortedEntries() -> [WholeBookTranscriptionQueueEntry] {
        let descriptor = FetchDescriptor<WholeBookTranscriptionQueueEntry>(
            sortBy: [SortDescriptor(\.orderIndex), SortDescriptor(\.addedAt)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    private func entry(for audiobookID: UUID) -> WholeBookTranscriptionQueueEntry? {
        sortedEntries().first { $0.audiobook?.id == audiobookID }
    }

    private func fetchAudiobook(id: UUID) -> Audiobook? {
        let descriptor = FetchDescriptor<Audiobook>(
            predicate: #Predicate { $0.id == id }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func markBookComplete(_ audiobook: Audiobook) {
        audiobook.subtitleGenerationStatus = .complete
        audiobook.subtitleLastCoveredEndTime = audiobook.duration
        audiobook.subtitleGenerationScope = nil
        audiobook.subtitleGenerationFromPlayhead = nil
        try? modelContext.save()
        bumpRevision()
    }

    private func reconcileOrphanedInProgressBooks() {
        let descriptor = FetchDescriptor<Audiobook>(
            predicate: #Predicate { book in
                book.subtitleGenerationStatusRaw == "inProgress"
            }
        )
        let orphaned = ((try? modelContext.fetch(descriptor)) ?? []).filter { book in
            book.subtitleGenerationScope == .wholeBook || book.subtitleGenerationScope == .fromCurrentPosition
        }
        let queuedIDs = Set(sortedEntries().compactMap(\.audiobook?.id))

        var nextIndex = (sortedEntries().map(\.orderIndex).max() ?? -1) + 1
        for book in orphaned where !queuedIDs.contains(book.id) {
            let fromPlayhead: TimeInterval?
            if book.subtitleGenerationScope == .fromCurrentPosition {
                fromPlayhead = book.subtitleGenerationFromPlayhead ?? book.currentPlaybackTime
            } else {
                fromPlayhead = nil
            }
            let entry = WholeBookTranscriptionQueueEntry(
                orderIndex: nextIndex,
                audiobook: book,
                status: .queued,
                fromPlayhead: fromPlayhead
            )
            modelContext.insert(entry)
            nextIndex += 1
        }
        try? modelContext.save()
    }

    private func snapshot(
        for entry: WholeBookTranscriptionQueueEntry,
        position: Int
    ) -> WholeBookQueueItemSnapshot? {
        guard let audiobook = entry.audiobook else { return nil }

        let segments = (try? subtitleStore.sortedSegments(for: audiobook.id)) ?? []
        let cues = (try? subtitleStore.sortedCues(for: audiobook.id)) ?? []
        let summary = SubtitleCoverageCalculator.summary(
            cues: cues,
            segments: segments,
            bookDuration: audiobook.duration
        )

        let allWindows: [SubtitleTimeWindow]
        if let fromPlayhead = entry.fromPlayhead {
            allWindows = SubtitleWindowPlanner.windowsFromCurrentSection(
                playhead: fromPlayhead,
                bookDuration: audiobook.duration
            )
        } else {
            allWindows = SubtitleWindowPlanner.wholeBookWindows(bookDuration: audiobook.duration)
        }
        let isActive = audiobook.id == activeAudiobookID

        let completed: Int
        let total: Int
        let message: String?
        let isPreparing: Bool

        if isActive && entry.status == .running {
            completed = activeProgress.completedWindows
            total = max(activeProgress.totalWindows, allWindows.count)
            message = activeProgress.message
            isPreparing = activeProgress.isPreparing
        } else {
            let uncovered = SubtitleSegmentPlanner.uncoveredWindows(
                bookDuration: audiobook.duration,
                segments: segments,
                fromPlayhead: entry.fromPlayhead
            )
            completed = max(0, allWindows.count - uncovered.count)
            total = max(allWindows.count, 1)
            message = nil
            isPreparing = false
        }

        let timeline = SubtitleCoverageTimelineMapper.timeline(
            segments: segments,
            bookDuration: audiobook.duration
        )

        return WholeBookQueueItemSnapshot(
            id: entry.id,
            audiobookID: audiobook.id,
            title: audiobook.title,
            author: audiobook.author,
            queuePosition: position,
            status: entry.status,
            isPreparing: isPreparing,
            coverageFraction: summary.coverageFraction,
            coverageTimeline: timeline,
            completedWindows: completed,
            totalWindows: total,
            progressMessage: message,
            failureMessage: entry.failureMessage
        )
    }

    private func bumpRevision() {
        revision &+= 1
        onRevisionChanged?()
    }
}

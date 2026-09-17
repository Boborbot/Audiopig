//
//  BookTranscriptionViewModel.swift
//  Audiopig
//

import Foundation
import Observation
import SwiftData

/// Transcription options for a specific library book, independent of the player.
@MainActor
@Observable
final class BookTranscriptionViewModel: TranscriptionSheetModeling, Identifiable {
    var id: UUID { audiobook.id }

    let audiobook: Audiobook
    var onShowTranscriptionQueue: (() -> Void)?

    private(set) var queueRevision: UInt64 = 0
    private(set) var savedSubtitleCueCount: Int = 0
    private(set) var savedSubtitleSegmentCount: Int = 0

    @ObservationIgnored
    private var subtitleCues: [SubtitleCueTiming] = []

    @ObservationIgnored
    private var subtitleSegments: [SubtitleTranscriptionSegmentTiming] = []

    private let modelContext: ModelContext
    private let subtitleStore: any SubtitleStoreProtocol
    private let transcriptionService: any SubtitleTranscriptionServiceProtocol
    private let wholeBookQueue: any WholeBookTranscriptionQueueServiceProtocol
    private let monetization: any MonetizationServiceProtocol
    private let playheadProvider: () -> TimeInterval
    private let onPaywallRequired: () -> Void
    private let onWillDeleteTranscription: () -> Void
    private let onTranscriptionDataChanged: () -> Void

    init(
        audiobook: Audiobook,
        modelContext: ModelContext,
        subtitleStore: any SubtitleStoreProtocol,
        transcriptionService: any SubtitleTranscriptionServiceProtocol,
        wholeBookQueue: any WholeBookTranscriptionQueueServiceProtocol,
        monetization: any MonetizationServiceProtocol,
        playheadProvider: @escaping () -> TimeInterval,
        onShowTranscriptionQueue: (() -> Void)?,
        onPaywallRequired: @escaping () -> Void,
        onWillDeleteTranscription: @escaping () -> Void,
        onTranscriptionDataChanged: @escaping () -> Void
    ) {
        self.audiobook = audiobook
        self.modelContext = modelContext
        self.subtitleStore = subtitleStore
        self.transcriptionService = transcriptionService
        self.wholeBookQueue = wholeBookQueue
        self.monetization = monetization
        self.playheadProvider = playheadProvider
        self.onShowTranscriptionQueue = onShowTranscriptionQueue
        self.onPaywallRequired = onPaywallRequired
        self.onWillDeleteTranscription = onWillDeleteTranscription
        self.onTranscriptionDataChanged = onTranscriptionDataChanged
        reload()
    }

    func refresh() {
        queueRevision = wholeBookQueue.revision
        reload()
    }

    var transcribeAsYouGoEnabled: Bool {
        get { audiobook.subtitlesTranscribeAsYouGo }
        set {
            audiobook.subtitlesTranscribeAsYouGo = newValue
            try? modelContext.save()
        }
    }

    var subtitlesSupported: Bool {
        transcriptionService.isSupported
    }

    var hasSavedSubtitles: Bool { savedSubtitleCueCount > 0 }

    var subtitleCoverageSummary: SubtitleCoverageSummary {
        _ = savedSubtitleCueCount
        _ = savedSubtitleSegmentCount
        return SubtitleCoverageCalculator.summary(
            cues: subtitleCues,
            segments: subtitleSegments,
            bookDuration: audiobook.duration
        )
    }

    var subtitleCoverageTimeline: SubtitleCoverageTimeline {
        _ = savedSubtitleSegmentCount
        return SubtitleCoverageTimelineMapper.timeline(
            segments: subtitleSegments,
            bookDuration: audiobook.duration
        )
    }

    var isInWholeBookTranscriptionQueue: Bool {
        _ = queueRevision
        return wholeBookQueue.queuePosition(for: audiobook.id) != nil
    }

    var wholeBookQueuePosition: Int? {
        _ = queueRevision
        return wholeBookQueue.queuePosition(for: audiobook.id)
    }

    var wholeBookJobState: WholeBookSubtitleJobStateKind {
        _ = queueRevision
        return WholeBookQueueSnapshotMapper.jobState(
            from: wholeBookQueue.snapshot(for: audiobook.id)
        )
    }

    var hasUncoveredSubtitleWindows: Bool {
        _ = savedSubtitleSegmentCount
        return !SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: audiobook.duration,
            segments: subtitleSegments
        ).isEmpty
    }

    var hasUncoveredSubtitleWindowsFromCurrentPosition: Bool {
        _ = savedSubtitleSegmentCount
        return !SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: audiobook.duration,
            segments: subtitleSegments,
            fromPlayhead: playheadProvider()
        ).isEmpty
    }

    func generateSubtitlesWholeBook() {
        enqueue(fromPlayhead: nil)
    }

    func generateSubtitlesFromCurrentPosition() {
        enqueue(fromPlayhead: playheadProvider())
    }

    func pauseWholeBookTranscription() {
        wholeBookQueue.pause(audiobookID: audiobook.id)
        refresh()
        onTranscriptionDataChanged()
    }

    func resumeWholeBookTranscription() {
        wholeBookQueue.resume(audiobookID: audiobook.id)
        refresh()
        onTranscriptionDataChanged()
    }

    func cancelWholeBookTranscription() {
        wholeBookQueue.cancel(audiobookID: audiobook.id)
        refresh()
        onTranscriptionDataChanged()
    }

    func exportSubtitles(format: SubtitleExportFormat) throws -> URL? {
        try SubtitleExportService.export(
            audiobook: audiobook,
            cues: subtitleCues,
            format: format
        )
    }

    func deleteSavedTranscription() {
        onWillDeleteTranscription()
        if wholeBookQueue.queuePosition(for: audiobook.id) != nil {
            wholeBookQueue.cancel(audiobookID: audiobook.id)
        }
        try? subtitleStore.deleteAllCues(for: audiobook)
        try? subtitleStore.deleteAllSegments(for: audiobook)
        audiobook.subtitleGenerationStatus = .notGenerated
        audiobook.subtitleLastCoveredEndTime = 0
        audiobook.subtitleGenerationScope = nil
        audiobook.subtitleGenerationFromPlayhead = nil
        try? modelContext.save()
        reload()
        onTranscriptionDataChanged()
    }

    private func enqueue(fromPlayhead: TimeInterval?) {
        guard subtitlesSupported else { return }
        switch wholeBookQueue.enqueue(audiobookID: audiobook.id, fromPlayhead: fromPlayhead) {
        case .paywallRequired:
            onPaywallRequired()
        case .enqueued, .alreadyInQueue, .alreadyComplete, .unsupported:
            refresh()
            onTranscriptionDataChanged()
        }
    }

    private func reload() {
        let loaded = (try? subtitleStore.sortedCues(for: audiobook.id)) ?? []
        subtitleCues = loaded.sorted {
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.orderIndex < $1.orderIndex
        }
        savedSubtitleCueCount = subtitleCues.count

        var segments = (try? subtitleStore.sortedSegments(for: audiobook.id)) ?? []
        if segments.isEmpty, !subtitleCues.isEmpty {
            let inferred = SubtitleSegmentPlanner.inferredSegmentsFromLegacyCues(
                cues: subtitleCues,
                bookDuration: audiobook.duration
            )
            try? subtitleStore.insertInferredSegments(inferred, audiobook: audiobook)
            segments = (try? subtitleStore.sortedSegments(for: audiobook.id)) ?? inferred
        }
        subtitleSegments = segments
        savedSubtitleSegmentCount = subtitleSegments.count
        queueRevision = wholeBookQueue.revision
    }
}

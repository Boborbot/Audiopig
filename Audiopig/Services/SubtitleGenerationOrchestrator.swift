//
//  SubtitleGenerationOrchestrator.swift
//  Audiopig
//
//  Subtitle pipeline: see docs/subtitles-architecture.md and .cursor/rules/subtitles.mdc
//

import Foundation

struct SubtitleGenerationProgress: Sendable {
    let completedWindows: Int
    let totalWindows: Int?
    let message: String
}

/// Coordinates window queueing and transcription for near-playhead and whole-book modes.
actor SubtitleGenerationOrchestrator {

    private let transcriptionService: any SubtitleTranscriptionServiceProtocol
    private var isCancelled = false
    private var isPaused = false

    init(transcriptionService: any SubtitleTranscriptionServiceProtocol) {
        self.transcriptionService = transcriptionService
    }

    func cancel() {
        isCancelled = true
        isPaused = false
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    private func waitIfPaused() async throws {
        while isPaused && !isCancelled {
            try await Task.sleep(for: .milliseconds(250))
            try Task.checkCancellation()
        }
        if isCancelled { throw SubtitleTranscriptionError.cancelled }
    }

    func generate(
        scope: SubtitleGenerationScope,
        playhead: TimeInterval,
        bookDuration: TimeInterval,
        chapters: [ResolvedChapter],
        existingSegments: [SubtitleTranscriptionSegmentTiming],
        localeIdentifier: String,
        onWindowComplete: @escaping @Sendable (SubtitleTimeWindow, [SubtitleCueTiming]) async throws -> Void,
        onProgress: @escaping @Sendable (SubtitleGenerationProgress) -> Void
    ) async throws {
        isCancelled = false

        try await transcriptionService.ensureLocaleReady(localeIdentifier: localeIdentifier) { download in
            onProgress(
                SubtitleGenerationProgress(
                    completedWindows: 0,
                    totalWindows: nil,
                    message: "Downloading language support… \(Int(download.fractionCompleted * 100))%"
                )
            )
        }

        switch scope {
        case .nearPlayhead:
            try await generateNearPlayhead(
                playhead: playhead,
                bookDuration: bookDuration,
                chapters: chapters,
                existingSegments: existingSegments,
                localeIdentifier: localeIdentifier,
                onWindowComplete: onWindowComplete,
                onProgress: onProgress
            )
        case .wholeBook:
            try await generateWholeBook(
                bookDuration: bookDuration,
                chapters: chapters,
                existingSegments: existingSegments,
                localeIdentifier: localeIdentifier,
                onWindowComplete: onWindowComplete,
                onProgress: onProgress
            )
        }
    }

    private func generateNearPlayhead(
        playhead: TimeInterval,
        bookDuration: TimeInterval,
        chapters: [ResolvedChapter],
        existingSegments: [SubtitleTranscriptionSegmentTiming],
        localeIdentifier: String,
        onWindowComplete: @escaping @Sendable (SubtitleTimeWindow, [SubtitleCueTiming]) async throws -> Void,
        onProgress: @escaping @Sendable (SubtitleGenerationProgress) -> Void
    ) async throws {
        guard let window = SubtitleSegmentPlanner.nearPlayheadTranscriptionWindow(
            playhead: playhead,
            bookDuration: bookDuration,
            segments: existingSegments
        ) else {
            return
        }

        try Task.checkCancellation()
        try await waitIfPaused()
        if isCancelled { throw SubtitleTranscriptionError.cancelled }

        onProgress(
            SubtitleGenerationProgress(
                completedWindows: 0,
                totalWindows: 1,
                message: "Transcribing near your position…"
            )
        )

        let newCues = try await transcribe(
            window: window,
            chapters: chapters,
            localeIdentifier: localeIdentifier
        )
        try await onWindowComplete(window, newCues)
    }

    private func generateWholeBook(
        bookDuration: TimeInterval,
        chapters: [ResolvedChapter],
        existingSegments: [SubtitleTranscriptionSegmentTiming],
        localeIdentifier: String,
        onWindowComplete: @escaping @Sendable (SubtitleTimeWindow, [SubtitleCueTiming]) async throws -> Void,
        onProgress: @escaping @Sendable (SubtitleGenerationProgress) -> Void
    ) async throws {
        let allWindows = SubtitleWindowPlanner.wholeBookWindows(bookDuration: bookDuration)
        let pending = SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: bookDuration,
            segments: existingSegments
        )

        for (index, window) in pending.enumerated() {
            try Task.checkCancellation()
            try await waitIfPaused()
            if isCancelled { throw SubtitleTranscriptionError.cancelled }

            onProgress(
                SubtitleGenerationProgress(
                    completedWindows: index,
                    totalWindows: allWindows.count,
                    message: "Transcribing entire book (\(index + 1) of \(pending.count))…"
                )
            )

            let newCues = try await transcribe(
                window: window,
                chapters: chapters,
                localeIdentifier: localeIdentifier
            )
            try await onWindowComplete(window, newCues)
        }
    }

    private func transcribe(
        window: SubtitleTimeWindow,
        chapters: [ResolvedChapter],
        localeIdentifier: String
    ) async throws -> [SubtitleCueTiming] {
        let segments = SubtitleAudioSegmentPlanner.segments(for: window, chapters: chapters)
        guard !segments.isEmpty else { return [] }

        var combined: [SubtitleCueTiming] = []
        for segment in segments {
            try Task.checkCancellation()
            if isCancelled { throw SubtitleTranscriptionError.cancelled }

            let cues = try await transcriptionService.transcribeWindow(
                fileURL: segment.fileURL,
                fileLocalStart: segment.fileLocalStart,
                fileLocalEnd: segment.fileLocalEnd,
                globalOffset: segment.globalOffset,
                localeIdentifier: localeIdentifier
            )
            combined.append(contentsOf: cues)
        }
        return combined.sorted { $0.startTime < $1.startTime }
    }
}

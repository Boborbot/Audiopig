//
//  SubtitleSegmentPlanner.swift
//  AudiopigShared
//
//  Subtitle pipeline: see docs/subtitles-architecture.md and .cursor/rules/subtitles.mdc
//

import Foundation

public enum SubtitleSegmentPlanner {

    public static let segmentMergeGap: TimeInterval = 5
    public static let fullCoverageThreshold = 0.99
    public static let legacyBackfillCueDensityThreshold = 0.50

    // MARK: - Segment algebra

    public static func merged(
        _ segments: [SubtitleTranscriptionSegmentTiming]
    ) -> [SubtitleTranscriptionSegmentTiming] {
        guard !segments.isEmpty else { return [] }

        let sorted = segments.sorted { $0.startTime < $1.startTime }
        var result: [SubtitleTranscriptionSegmentTiming] = []
        var current = sorted[0]

        for segment in sorted.dropFirst() {
            if segment.startTime <= current.endTime + segmentMergeGap {
                current = SubtitleTranscriptionSegmentTiming(
                    startTime: current.startTime,
                    endTime: max(current.endTime, segment.endTime)
                )
            } else {
                result.append(current)
                current = segment
            }
        }
        result.append(current)
        return result
    }

    public static func coveredDuration(
        in window: SubtitleTimeWindow,
        segments: [SubtitleTranscriptionSegmentTiming]
    ) -> TimeInterval {
        merged(segments).reduce(0) { partial, segment in
            let start = max(window.globalStart, segment.startTime)
            let end = min(window.globalEnd, segment.endTime)
            return partial + max(0, end - start)
        }
    }

    public static func fullyCovers(
        window: SubtitleTimeWindow,
        segments: [SubtitleTranscriptionSegmentTiming]
    ) -> Bool {
        guard window.duration > 0 else { return true }
        return coveredDuration(in: window, segments: segments) / window.duration >= fullCoverageThreshold
    }

    public static func needsTranscription(
        window: SubtitleTimeWindow,
        segments: [SubtitleTranscriptionSegmentTiming]
    ) -> Bool {
        !fullyCovers(window: window, segments: segments)
    }

    public static func uncoveredWindows(
        bookDuration: TimeInterval,
        segments: [SubtitleTranscriptionSegmentTiming],
        windowDuration: TimeInterval = SubtitleWindowPlanner.defaultWindowDuration
    ) -> [SubtitleTimeWindow] {
        SubtitleWindowPlanner.wholeBookWindows(bookDuration: bookDuration, windowDuration: windowDuration)
            .filter { needsTranscription(window: $0, segments: segments) }
    }

    public static func forwardSegmentCoverageEnd(
        from playhead: TimeInterval,
        segments: [SubtitleTranscriptionSegmentTiming]
    ) -> TimeInterval {
        guard !segments.isEmpty else { return playhead }

        let sorted = merged(segments)
            .filter { $0.endTime > playhead - 1 }
            .sorted { $0.startTime < $1.startTime }

        var edge = playhead
        for segment in sorted {
            if segment.startTime > edge + segmentMergeGap { break }
            edge = max(edge, segment.endTime)
        }
        return edge
    }

    // MARK: - Near-playhead queue

    /// The single window to transcribe for one near-playhead generation pass.
    public static func nearPlayheadTranscriptionWindow(
        playhead: TimeInterval,
        bookDuration: TimeInterval,
        segments: [SubtitleTranscriptionSegmentTiming],
        windowDuration: TimeInterval = SubtitleWindowPlanner.defaultWindowDuration
    ) -> SubtitleTimeWindow? {
        guard bookDuration > 0, windowDuration > 0 else { return nil }

        let playheadWindow = SubtitleWindowPlanner.initialNearPlayheadWindow(
            playhead: playhead,
            bookDuration: bookDuration,
            windowDuration: windowDuration
        )
        if needsTranscription(window: playheadWindow, segments: segments) {
            return playheadWindow
        }

        let forwardEdge = forwardSegmentCoverageEnd(from: playhead, segments: segments)
        let forward = SubtitleTimeWindow(
            globalStart: forwardEdge,
            globalEnd: min(bookDuration, forwardEdge + windowDuration)
        )
        if forward.globalEnd > forward.globalStart,
           needsTranscription(window: forward, segments: segments) {
            return forward
        }

        let uncovered = uncoveredWindows(
            bookDuration: bookDuration,
            segments: segments,
            windowDuration: windowDuration
        )
        guard let nearest = uncovered.min(by: { distance(from: playhead, to: $0) < distance(from: playhead, to: $1) }) else {
            return nil
        }
        return nearest
    }

    public static func shouldAutoGenerateNearPlayhead(
        playhead: TimeInterval,
        bookDuration: TimeInterval,
        segments: [SubtitleTranscriptionSegmentTiming],
        cues: [SubtitleCueTiming],
        approachLeadTime: TimeInterval = SubtitleWindowPlanner.playheadLeadIn
    ) -> Bool {
        guard bookDuration > 0 else { return false }
        guard !SubtitleCueResolver.hasActiveCue(at: playhead, cues: cues) else { return false }

        if uncoveredWindows(bookDuration: bookDuration, segments: segments).isEmpty {
            return false
        }

        let forwardEdge = forwardSegmentCoverageEnd(from: playhead, segments: segments)
        guard playhead + approachLeadTime >= forwardEdge else { return false }

        let forwardWindow = SubtitleTimeWindow(
            globalStart: forwardEdge,
            globalEnd: min(bookDuration, forwardEdge + SubtitleWindowPlanner.defaultWindowDuration)
        )
        guard forwardWindow.globalEnd > forwardWindow.globalStart else { return false }
        return needsTranscription(window: forwardWindow, segments: segments)
    }

    // MARK: - Legacy backfill

    public static func inferredSegmentsFromLegacyCues(
        cues: [SubtitleCueTiming],
        bookDuration: TimeInterval,
        windowDuration: TimeInterval = SubtitleWindowPlanner.defaultWindowDuration,
        densityThreshold: Double = legacyBackfillCueDensityThreshold
    ) -> [SubtitleTranscriptionSegmentTiming] {
        guard !cues.isEmpty, bookDuration > 0 else { return [] }

        return SubtitleWindowPlanner.wholeBookWindows(bookDuration: bookDuration, windowDuration: windowDuration)
            .compactMap { window in
                guard window.duration > 0 else { return nil }
                let cueDuration = cueCoveredDuration(in: window, cues: cues)
                guard cueDuration / window.duration >= densityThreshold else { return nil }
                return SubtitleTranscriptionSegmentTiming(
                    startTime: window.globalStart,
                    endTime: window.globalEnd
                )
            }
    }

    // MARK: - Private

    private static func distance(from playhead: TimeInterval, to window: SubtitleTimeWindow) -> TimeInterval {
        if window.contains(playhead) { return 0 }
        if playhead < window.globalStart { return window.globalStart - playhead }
        return playhead - window.globalEnd
    }

    private static func cueCoveredDuration(
        in window: SubtitleTimeWindow,
        cues: [SubtitleCueTiming]
    ) -> TimeInterval {
        cues.reduce(0) { partial, cue in
            let start = max(window.globalStart, cue.startTime)
            let end = min(window.globalEnd, cue.endTime)
            return partial + max(0, end - start)
        }
    }
}

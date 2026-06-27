//
//  SubtitleCoverageTimeline.swift
//  AudiopigShared
//

import Foundation

/// A contiguous transcribed span on the book timeline, for coverage visuals.
public struct SubtitleCoverageTimelineRun: Sendable, Equatable, Identifiable {
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public var id: String { "\(startTime)-\(endTime)" }

    public var duration: TimeInterval {
        max(0, endTime - startTime)
    }

    public init(startTime: TimeInterval, endTime: TimeInterval) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

/// Proportional transcription coverage for timeline bar visuals.
public struct SubtitleCoverageTimeline: Sendable, Equatable {
    public let bookDuration: TimeInterval
    public let runs: [SubtitleCoverageTimelineRun]
    public let coverageFraction: Double
    public let uncoveredWindowCount: Int

    public init(
        bookDuration: TimeInterval,
        runs: [SubtitleCoverageTimelineRun],
        coverageFraction: Double,
        uncoveredWindowCount: Int
    ) {
        self.bookDuration = bookDuration
        self.runs = runs
        self.coverageFraction = coverageFraction
        self.uncoveredWindowCount = uncoveredWindowCount
    }
}

public enum SubtitleCoverageTimelineMapper {

    /// Builds a proportional timeline from merged transcription segments.
    public static func timeline(
        segments: [SubtitleTranscriptionSegmentTiming],
        bookDuration: TimeInterval,
        windowDuration: TimeInterval = SubtitleWindowPlanner.defaultWindowDuration
    ) -> SubtitleCoverageTimeline {
        guard bookDuration > 0 else {
            return SubtitleCoverageTimeline(
                bookDuration: 0,
                runs: [],
                coverageFraction: 0,
                uncoveredWindowCount: 0
            )
        }

        let runs = SubtitleSegmentPlanner.merged(segments).compactMap { segment -> SubtitleCoverageTimelineRun? in
            let start = max(0, segment.startTime)
            let end = min(bookDuration, segment.endTime)
            guard end > start else { return nil }
            return SubtitleCoverageTimelineRun(startTime: start, endTime: end)
        }

        let transcribedDuration = runs.reduce(0) { $0 + $1.duration }
        let fraction = min(1, transcribedDuration / bookDuration)
        let uncoveredCount = SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: bookDuration,
            segments: segments,
            windowDuration: windowDuration
        ).count

        return SubtitleCoverageTimeline(
            bookDuration: bookDuration,
            runs: runs,
            coverageFraction: fraction,
            uncoveredWindowCount: uncoveredCount
        )
    }
}

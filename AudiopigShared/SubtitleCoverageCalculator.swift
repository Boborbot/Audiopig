//
//  SubtitleCoverageCalculator.swift
//  AudiopigShared
//

import Foundation

public struct SubtitleCoverageSummary: Sendable, Equatable {
    public let cueCount: Int
    public let bookDuration: TimeInterval
    public let coveredWindowCount: Int
    public let totalWindowCount: Int
    public let uncoveredWindowCount: Int
    public let transcribedDurationFraction: Double
    public let estimatedStorageBytes: Int

    public var coverageFraction: Double {
        transcribedDurationFraction
    }

    public var formattedStorageSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(estimatedStorageBytes), countStyle: .file)
    }
}

public enum SubtitleCoverageCalculator {

    /// Estimates how much of the book timeline has been submitted to ASR.
    public static func summary(
        cues: [SubtitleCueTiming],
        segments: [SubtitleTranscriptionSegmentTiming],
        bookDuration: TimeInterval,
        windowDuration: TimeInterval = SubtitleWindowPlanner.defaultWindowDuration
    ) -> SubtitleCoverageSummary {
        let windows = SubtitleWindowPlanner.wholeBookWindows(
            bookDuration: bookDuration,
            windowDuration: windowDuration
        )
        let covered = windows.filter {
            SubtitleSegmentPlanner.fullyCovers(window: $0, segments: segments)
        }.count

        let merged = SubtitleSegmentPlanner.merged(segments)
        let transcribedDuration = merged.reduce(0) { $0 + $1.duration }
        let fraction = bookDuration > 0 ? min(1, transcribedDuration / bookDuration) : 0

        let bytes = cues.reduce(0) { partial, cue in
            partial + cue.text.utf8.count + 32
        }

        return SubtitleCoverageSummary(
            cueCount: cues.count,
            bookDuration: bookDuration,
            coveredWindowCount: covered,
            totalWindowCount: windows.count,
            uncoveredWindowCount: max(0, windows.count - covered),
            transcribedDurationFraction: fraction,
            estimatedStorageBytes: bytes
        )
    }
}

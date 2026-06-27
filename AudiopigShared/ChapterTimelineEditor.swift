//
//  ChapterTimelineEditor.swift
//  AudiopigShared
//

import Foundation

/// Pure helpers for applying chapter list edits to timeline metadata.
public enum ChapterTimelineEditor {

    /// Multi-file (or otherwise stacked) books use cumulative global start times.
    /// Single-file books keep each chapter's in-file start time when reordering.
    public static func usesStackedTimeline(fileURLs: some Collection<URL>) -> Bool {
        Set(fileURLs).count > 1
    }

    /// Builds cumulative start times for chapters played in the given order.
    public static func stackedStartTimes(durations: [TimeInterval]) -> [TimeInterval] {
        var offset: TimeInterval = 0
        return durations.map { duration in
            let start = offset
            offset += duration
            return start
        }
    }

    public static func totalDuration(durations: [TimeInterval]) -> TimeInterval {
        durations.reduce(0, +)
    }

    public static func sanitizedTitle(_ raw: String, fallback: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}

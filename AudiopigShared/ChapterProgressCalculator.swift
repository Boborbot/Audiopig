//
//  ChapterProgressCalculator.swift
//  AudiopigShared
//

import Foundation

public struct WatchChapterTiming: Sendable, Equatable {
    public let startTime: TimeInterval
    public let duration: TimeInterval

    public init(startTime: TimeInterval, duration: TimeInterval) {
        self.startTime = startTime
        self.duration = duration
    }
}

public struct WatchChapterProgress: Sendable, Equatable {
    public let chapterIndex: Int
    public let chapterElapsed: TimeInterval
    public let chapterDuration: TimeInterval
    public let chapterProgress: Double

    public init(
        chapterIndex: Int,
        chapterElapsed: TimeInterval,
        chapterDuration: TimeInterval,
        chapterProgress: Double
    ) {
        self.chapterIndex = chapterIndex
        self.chapterElapsed = chapterElapsed
        self.chapterDuration = chapterDuration
        self.chapterProgress = chapterProgress
    }
}

public enum ChapterProgressCalculator {
    /// Resolves chapter-scoped progress for a global timeline position.
    public static func progress(
        globalTime: TimeInterval,
        chapters: [WatchChapterTiming]
    ) -> WatchChapterProgress {
        guard !chapters.isEmpty else {
            return WatchChapterProgress(
                chapterIndex: 0,
                chapterElapsed: 0,
                chapterDuration: 0,
                chapterProgress: 0
            )
        }

        let index = resolveChapterIndex(for: globalTime, chapters: chapters)
        let chapter = chapters[index]
        let elapsed = max(0, globalTime - chapter.startTime)
        let duration = max(0, chapter.duration)
        let progress = duration > 0 ? min(1, elapsed / duration) : 0

        return WatchChapterProgress(
            chapterIndex: index,
            chapterElapsed: elapsed,
            chapterDuration: duration,
            chapterProgress: progress
        )
    }

    public static func resolveChapterIndex(
        for globalTime: TimeInterval,
        chapters: [WatchChapterTiming]
    ) -> Int {
        guard !chapters.isEmpty else { return 0 }
        var low = 0
        var high = chapters.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let chapter = chapters[mid]
            let end = chapter.startTime + chapter.duration
            if globalTime >= chapter.startTime && globalTime < end {
                return mid
            } else if globalTime < chapter.startTime {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        return max(0, chapters.count - 1)
    }
}

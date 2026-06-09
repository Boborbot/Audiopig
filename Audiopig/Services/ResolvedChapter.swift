//
//  ResolvedChapter.swift
//  Audiopig
//

import Foundation

/// An immutable value-type snapshot of a Chapter taken at load time.
///
/// Capturing chapter data as a value type insulates the AudioEngine from
/// live SwiftData model mutations or deletions that could occur during playback.
struct ResolvedChapter: Equatable, Sendable {
    let id: UUID
    let title: String
    let startTime: TimeInterval
    let duration: TimeInterval
    let orderIndex: Int
    let fileURL: URL

    init(from chapter: Chapter) {
        self.id = chapter.id
        self.title = chapter.title
        self.startTime = chapter.startTime
        self.duration = chapter.duration
        self.orderIndex = chapter.orderIndex
        self.fileURL = chapter.fileURL
    }
}

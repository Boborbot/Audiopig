//
//  FinishedRecord.swift
//  Audiopig
//
//  An immutable snapshot created every time a book is marked finished.
//  Survives book deletion — so stats accumulate indefinitely.
//  Designed for future "Wrapped"-style summaries.
//

import Foundation
import SwiftData

@Model
final class FinishedRecord {

    // MARK: - Identity

    @Attribute(.unique) var id: UUID

    // MARK: - Book snapshot (preserved even if the book is later deleted)

    var audiobookID: UUID
    var title: String
    var author: String

    // MARK: - Time data

    /// Total length of the audiobook in seconds.
    var totalSeconds: TimeInterval
    /// How far into the book the user had actually listened when they marked it finished.
    var listenedSeconds: TimeInterval
    /// Wall-clock moment the user marked this book finished.
    var finishedAt: Date

    // MARK: - Structure

    var chapterCount: Int

    // MARK: - Intent

    /// `true` when the user swiped to mark it done before listening all the way through.
    /// `false` when playback reached the natural end.
    var wasManuallyMarked: Bool

    // MARK: - Computed (for Wrapped-style queries)

    /// 0–1 fraction actually listened before finishing.
    var listenedFraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return min(1, listenedSeconds / totalSeconds)
    }

    /// Rough "hours invested" label, e.g. "3 hr 14 min".
    var listenedLabel: String {
        let total = Int(listenedSeconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 && m > 0 { return "\(h) hr \(m) min" }
        if h > 0           { return "\(h) hr" }
        if m > 0           { return "\(m) min" }
        return "< 1 min"
    }

    // MARK: - Init

    init(
        id: UUID = UUID(),
        audiobookID: UUID,
        title: String,
        author: String,
        totalSeconds: TimeInterval,
        listenedSeconds: TimeInterval,
        finishedAt: Date = Date(),
        chapterCount: Int,
        wasManuallyMarked: Bool
    ) {
        self.id               = id
        self.audiobookID      = audiobookID
        self.title            = title
        self.author           = author
        self.totalSeconds     = totalSeconds
        self.listenedSeconds  = listenedSeconds
        self.finishedAt       = finishedAt
        self.chapterCount     = chapterCount
        self.wasManuallyMarked = wasManuallyMarked
    }
}

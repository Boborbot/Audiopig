//
//  WatchChapterSummary.swift
//  AudiopigShared
//

import Foundation

public struct WatchChapterSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let startTime: TimeInterval
    public let duration: TimeInterval
    public let orderIndex: Int

    public init(
        id: UUID,
        title: String,
        startTime: TimeInterval,
        duration: TimeInterval,
        orderIndex: Int
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.duration = duration
        self.orderIndex = orderIndex
    }
}

public struct WatchChaptersPayload: Codable, Sendable, Equatable {
    public let bookID: UUID
    public let chapters: [WatchChapterSummary]

    public init(bookID: UUID, chapters: [WatchChapterSummary]) {
        self.bookID = bookID
        self.chapters = chapters
    }
}

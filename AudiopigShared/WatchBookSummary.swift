//
//  WatchBookSummary.swift
//  AudiopigShared
//

import Foundation

public struct WatchBookSummary: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let title: String
    public let author: String
    public let duration: TimeInterval
    public let currentPlaybackTime: TimeInterval
    public let lastPlayedAt: Date?
    /// JPEG thumbnail, max ~120×120. Omitted when nil to save bandwidth.
    public let thumbnailJPEG: Data?

    public init(
        id: UUID,
        title: String,
        author: String,
        duration: TimeInterval,
        currentPlaybackTime: TimeInterval,
        lastPlayedAt: Date?,
        thumbnailJPEG: Data? = nil
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.currentPlaybackTime = currentPlaybackTime
        self.lastPlayedAt = lastPlayedAt
        self.thumbnailJPEG = thumbnailJPEG
    }
}

public struct WatchRecentBooksPayload: Codable, Sendable, Equatable {
    public let books: [WatchBookSummary]

    public init(books: [WatchBookSummary]) {
        self.books = books
    }
}

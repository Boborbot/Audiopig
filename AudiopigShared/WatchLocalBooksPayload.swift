//
//  WatchLocalBooksPayload.swift
//  AudiopigShared
//

import Foundation

public struct WatchLocalBooksPayload: Codable, Sendable, Equatable {
    public let books: [WatchBookSummary]
    public let usedBytes: Int64
    public let budgetBytes: Int64

    public init(books: [WatchBookSummary], usedBytes: Int64, budgetBytes: Int64) {
        self.books = books
        self.usedBytes = usedBytes
        self.budgetBytes = budgetBytes
    }

    /// Library snapshot without thumbnails — safe for WatchConnectivity command payloads.
    public func slimSyncCopy() -> WatchLocalBooksPayload {
        WatchLocalBooksPayload(
            books: books.map {
                WatchBookSummary(
                    id: $0.id,
                    title: $0.title,
                    author: $0.author,
                    duration: $0.duration,
                    currentPlaybackTime: $0.currentPlaybackTime,
                    lastPlayedAt: $0.lastPlayedAt,
                    thumbnailJPEG: nil
                )
            },
            usedBytes: usedBytes,
            budgetBytes: budgetBytes
        )
    }
}

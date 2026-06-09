//
//  Audiobook.swift
//  Audiopig
//

import Foundation
import SwiftData

@Model
final class Audiobook {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var duration: TimeInterval
    var currentPlaybackTime: TimeInterval
    @Attribute(.externalStorage) var coverArtwork: Data?
    var fileURL: URL

    @Relationship(deleteRule: .cascade, inverse: \Chapter.audiobook)
    var chapters: [Chapter]

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.audiobook)
    var bookmarks: [Bookmark]

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        duration: TimeInterval,
        currentPlaybackTime: TimeInterval = 0,
        coverArtwork: Data? = nil,
        fileURL: URL,
        chapters: [Chapter] = [],
        bookmarks: [Bookmark] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.currentPlaybackTime = currentPlaybackTime
        self.coverArtwork = coverArtwork
        self.fileURL = fileURL
        self.chapters = chapters
        self.bookmarks = bookmarks
    }
}

//
//  Audiobook.swift
//  Audiopig
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Audiobook {
    @Attribute(.unique) var id: UUID
    var title: String
    var author: String
    var duration: TimeInterval
    var currentPlaybackTime: TimeInterval
    var isManuallyFinished: Bool
    @Attribute(.externalStorage) var coverArtwork: Data?
    var fileURL: URL

    /// True when the user has explicitly marked this book finished, or when
    /// playback has reached the end naturally.
    var isFinished: Bool {
        isManuallyFinished || (duration > 0 && currentPlaybackTime >= duration)
    }

    /// A stable accent color derived from the book's UUID.
    /// The same book always gets the same color; no storage required.
    var placeholderColor: Color {
        let palette: [Color] = [
            Color(red: 0.35, green: 0.40, blue: 0.75), // indigo
            Color(red: 0.22, green: 0.57, blue: 0.60), // teal
            Color(red: 0.75, green: 0.38, blue: 0.20), // burnt orange
            Color(red: 0.52, green: 0.28, blue: 0.70), // purple
            Color(red: 0.72, green: 0.25, blue: 0.48), // rose
            Color(red: 0.18, green: 0.55, blue: 0.68), // cyan
            Color(red: 0.22, green: 0.60, blue: 0.45), // mint
            Color(red: 0.50, green: 0.35, blue: 0.25), // brown
        ]
        let index = abs(id.hashValue) % palette.count
        return palette[index]
    }

    @Relationship(deleteRule: .cascade, inverse: \Chapter.audiobook)
    var chapters: [Chapter]

    @Relationship(deleteRule: .cascade, inverse: \Bookmark.audiobook)
    var bookmarks: [Bookmark]

    var folder: Folder?

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        duration: TimeInterval,
        currentPlaybackTime: TimeInterval = 0,
        isManuallyFinished: Bool = false,
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
        self.isManuallyFinished = isManuallyFinished
        self.coverArtwork = coverArtwork
        self.fileURL = fileURL
        self.chapters = chapters
        self.bookmarks = bookmarks
    }
}

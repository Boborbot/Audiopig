//
//  Folder.swift
//  Audiopig
//

import Foundation
import SwiftData

@Model
final class Folder {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    @Attribute(.externalStorage) var coverArtwork: Data?

    @Relationship(deleteRule: .nullify, inverse: \Audiobook.folder)
    var audiobooks: [Audiobook]

    var bookCount: Int { audiobooks.count }

    var sortedAudiobooks: [Audiobook] {
        audiobooks.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    init(id: UUID = UUID(), title: String, createdAt: Date = Date(), coverArtwork: Data? = nil) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.coverArtwork = coverArtwork
        self.audiobooks = []
    }
}

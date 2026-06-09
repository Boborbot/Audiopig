//
//  Bookmark.swift
//  Audiopig
//

import Foundation
import SwiftData

@Model
final class Bookmark {
    @Attribute(.unique) var id: UUID
    var title: String
    var timestamp: TimeInterval
    var createdAt: Date

    var audiobook: Audiobook?

    init(
        id: UUID = UUID(),
        title: String,
        timestamp: TimeInterval,
        createdAt: Date = .now,
        audiobook: Audiobook? = nil
    ) {
        self.id = id
        self.title = title
        self.timestamp = timestamp
        self.createdAt = createdAt
        self.audiobook = audiobook
    }
}

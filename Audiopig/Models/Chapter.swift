//
//  Chapter.swift
//  Audiopig
//

import Foundation
import SwiftData

@Model
final class Chapter {
    @Attribute(.unique) var id: UUID
    var title: String
    var duration: TimeInterval
    var startTime: TimeInterval
    var orderIndex: Int
    var fileURL: URL

    var audiobook: Audiobook?

    init(
        id: UUID = UUID(),
        title: String,
        duration: TimeInterval,
        startTime: TimeInterval,
        orderIndex: Int,
        fileURL: URL,
        audiobook: Audiobook? = nil
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.startTime = startTime
        self.orderIndex = orderIndex
        self.fileURL = fileURL
        self.audiobook = audiobook
    }
}

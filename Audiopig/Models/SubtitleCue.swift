//
//  SubtitleCue.swift
//  Audiopig
//

import Foundation
import SwiftData

@Model
final class SubtitleCue {
    @Attribute(.unique) var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval
    var text: String
    var orderIndex: Int

    var audiobook: Audiobook?

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        orderIndex: Int,
        audiobook: Audiobook? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.orderIndex = orderIndex
        self.audiobook = audiobook
    }

    var timing: SubtitleCueTiming {
        SubtitleCueTiming(
            startTime: startTime,
            endTime: endTime,
            text: text,
            orderIndex: orderIndex
        )
    }
}

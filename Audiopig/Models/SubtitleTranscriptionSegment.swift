//
//  SubtitleTranscriptionSegment.swift
//  Audiopig
//

import Foundation
import SwiftData

@Model
final class SubtitleTranscriptionSegment {
    @Attribute(.unique) var id: UUID
    var startTime: TimeInterval
    var endTime: TimeInterval

    var audiobook: Audiobook?

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        audiobook: Audiobook? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.audiobook = audiobook
    }

    var timing: SubtitleTranscriptionSegmentTiming {
        SubtitleTranscriptionSegmentTiming(startTime: startTime, endTime: endTime)
    }
}

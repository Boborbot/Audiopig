//
//  WholeBookTranscriptionQueueEntry.swift
//  Audiopig
//

import Foundation
import SwiftData

@Model
final class WholeBookTranscriptionQueueEntry {
    var id: UUID = UUID()
    var orderIndex: Int = 0
    var addedAt: Date = Date()
    var statusRaw: String = WholeBookQueueEntryStatus.queued.rawValue
    var failureMessage: String?
    /// Playhead captured when enqueueing "from current position". `nil` means the entire book.
    var fromPlayhead: TimeInterval? = nil

    var audiobook: Audiobook?

    var status: WholeBookQueueEntryStatus {
        get { WholeBookQueueEntryStatus(rawValue: statusRaw) ?? .queued }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        audiobook: Audiobook,
        status: WholeBookQueueEntryStatus = .queued,
        fromPlayhead: TimeInterval? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.addedAt = Date()
        self.statusRaw = status.rawValue
        self.fromPlayhead = fromPlayhead
        self.audiobook = audiobook
    }
}

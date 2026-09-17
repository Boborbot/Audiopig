//
//  SubtitleGenerationScope.swift
//  AudiopigShared
//

import Foundation

/// How subtitle transcription is scheduled for an audiobook.
public enum SubtitleGenerationScope: String, Codable, Sendable, CaseIterable {
    /// Transcribe a window around the playhead first, then expand outward.
    case nearPlayhead
    /// Transcribe the full book timeline in fixed windows from start to end.
    case wholeBook
    /// Transcribe from the 10-minute section containing the playhead through the end of the book.
    case fromCurrentPosition
}

public enum SubtitleGenerationStatus: String, Codable, Sendable, CaseIterable {
    case notGenerated
    case inProgress
    case paused
    case partial
    case complete
    case failed
}

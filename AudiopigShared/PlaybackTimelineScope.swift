//
//  PlaybackTimelineScope.swift
//  AudiopigShared
//

import Foundation

/// Whether elapsed/duration/progress are scoped to the whole book or the active chapter.
public enum PlaybackTimelineScope: String, Codable, Sendable, Equatable {
    case entireBook
    case currentChapter
}


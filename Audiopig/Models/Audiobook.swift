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
    /// Resume position in the audiobook timeline. Updated on seek and periodically while playing.
    var currentPlaybackTime: TimeInterval
    /// Last playback speed used for this book when universal speed is disabled.
    /// When `nil`, the app's default playback speed is used until the user changes speed for this book.
    var lastPlaybackSpeed: Float? = nil
    /// Last EQ preset used for this book when universal audio enhancement is disabled.
    var lastEQPresetID: String? = nil
    /// Whether EQ is active for this book. `nil` = legacy; migrate from `lastEQPresetID`.
    var lastEQEnabled: Bool? = nil
    /// Last Voice Boost level for this book when universal audio enhancement is disabled.
    var lastVoiceBoostLevel: Int? = nil
    /// Legacy per-book Voice Boost on/off. Migrated to `lastVoiceBoostLevel` on read.
    var lastVoiceBoostEnabled: Bool? = nil
    /// Last time this book was opened or had playback position saved. Used for Watch recent list.
    var lastPlayedAt: Date? = nil
    /// When the book was added to the library. `nil` for legacy records until backfilled from file metadata.
    var addedAt: Date? = nil
    /// Wall-clock content seconds actually heard while playback was running.
    /// Grows only from small forward deltas between time-observer ticks — never from seeks or scrubs.
    var accumulatedListeningSeconds: TimeInterval = 0
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

    @Relationship(deleteRule: .cascade, inverse: \SubtitleCue.audiobook)
    var subtitleCues: [SubtitleCue]

    @Relationship(deleteRule: .cascade, inverse: \SubtitleTranscriptionSegment.audiobook)
    var subtitleTranscriptionSegments: [SubtitleTranscriptionSegment]

    /// Raw `SubtitleGenerationStatus` value for SwiftData storage.
    var subtitleGenerationStatusRaw: String = SubtitleGenerationStatus.notGenerated.rawValue
    /// BCP-47 locale used for on-device transcription, e.g. `en-US`.
    var subtitleLocaleIdentifier: String?
    /// Raw `SubtitleGenerationScope` value (`nearPlayhead` or `wholeBook`).
    var subtitleGenerationScopeRaw: String?
    /// Whole-book mode resume checkpoint on the global timeline.
    var subtitleLastCoveredEndTime: TimeInterval = 0
    /// When true, near-playhead transcription starts automatically as the listener approaches saved coverage.
    var subtitlesTranscribeAsYouGo: Bool = false

    var folder: Folder?

    var subtitleGenerationStatus: SubtitleGenerationStatus {
        get { SubtitleGenerationStatus(rawValue: subtitleGenerationStatusRaw) ?? .notGenerated }
        set { subtitleGenerationStatusRaw = newValue.rawValue }
    }

    var subtitleGenerationScope: SubtitleGenerationScope? {
        get {
            guard let raw = subtitleGenerationScopeRaw else { return nil }
            return SubtitleGenerationScope(rawValue: raw)
        }
        set { subtitleGenerationScopeRaw = newValue?.rawValue }
    }

    var hasSubtitleCoverage: Bool {
        subtitleGenerationStatus == .partial || subtitleGenerationStatus == .complete
    }

    init(
        id: UUID = UUID(),
        title: String,
        author: String,
        duration: TimeInterval,
        currentPlaybackTime: TimeInterval = 0,
        lastPlaybackSpeed: Float? = nil,
        lastEQPresetID: String? = nil,
        lastEQEnabled: Bool? = nil,
        lastVoiceBoostLevel: Int? = nil,
        lastVoiceBoostEnabled: Bool? = nil,
        isManuallyFinished: Bool = false,
        coverArtwork: Data? = nil,
        fileURL: URL,
        chapters: [Chapter] = [],
        bookmarks: [Bookmark] = [],
        subtitleCues: [SubtitleCue] = [],
        subtitleTranscriptionSegments: [SubtitleTranscriptionSegment] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.currentPlaybackTime = currentPlaybackTime
        self.lastPlaybackSpeed = lastPlaybackSpeed
        self.lastEQPresetID = lastEQPresetID
        self.lastEQEnabled = lastEQEnabled
        self.lastVoiceBoostLevel = lastVoiceBoostLevel
        self.lastVoiceBoostEnabled = lastVoiceBoostEnabled
        self.isManuallyFinished = isManuallyFinished
        self.coverArtwork = coverArtwork
        self.fileURL = fileURL
        self.chapters = chapters
        self.bookmarks = bookmarks
        self.subtitleCues = subtitleCues
        self.subtitleTranscriptionSegments = subtitleTranscriptionSegments
    }
}

//
//  WatchPlaybackSnapshot.swift
//  AudiopigShared
//

import Foundation

public struct WatchPlaybackSnapshot: Codable, Sendable, Equatable {
    public let revision: UInt64
    public let bookID: UUID?
    public let title: String
    public let author: String
    public let chapterTitle: String
    public let playbackState: WatchPlaybackState
    public let playbackSpeed: Float
    public let skipForwardSeconds: TimeInterval
    public let skipBackwardSeconds: TimeInterval
    public let chapterIndex: Int
    public let chapterCount: Int
    public let chapterElapsed: TimeInterval
    public let chapterDuration: TimeInterval
    public let chapterProgress: Double
    public let globalCurrentTime: TimeInterval
    public let globalDuration: TimeInterval
    /// Mirrors iPhone player timebar scope; optional for older payloads.
    public let playbackTimelineScope: PlaybackTimelineScope?
    public let systemVolume: Float
    public let source: WatchPlaybackSource
    /// JPEG artwork ~200×200; sent on book change only.
    public let artworkJPEG: Data?
    public let updatedAt: Date

    public init(
        revision: UInt64,
        bookID: UUID?,
        title: String,
        author: String,
        chapterTitle: String,
        playbackState: WatchPlaybackState,
        playbackSpeed: Float,
        skipForwardSeconds: TimeInterval,
        skipBackwardSeconds: TimeInterval,
        chapterIndex: Int,
        chapterCount: Int,
        chapterElapsed: TimeInterval,
        chapterDuration: TimeInterval,
        chapterProgress: Double,
        globalCurrentTime: TimeInterval,
        globalDuration: TimeInterval,
        playbackTimelineScope: PlaybackTimelineScope? = nil,
        systemVolume: Float,
        source: WatchPlaybackSource,
        artworkJPEG: Data?,
        updatedAt: Date = .now
    ) {
        self.revision = revision
        self.bookID = bookID
        self.title = title
        self.author = author
        self.chapterTitle = chapterTitle
        self.playbackState = playbackState
        self.playbackSpeed = playbackSpeed
        self.skipForwardSeconds = skipForwardSeconds
        self.skipBackwardSeconds = skipBackwardSeconds
        self.chapterIndex = chapterIndex
        self.chapterCount = chapterCount
        self.chapterElapsed = chapterElapsed
        self.chapterDuration = chapterDuration
        self.chapterProgress = chapterProgress
        self.globalCurrentTime = globalCurrentTime
        self.globalDuration = globalDuration
        self.playbackTimelineScope = playbackTimelineScope
        self.systemVolume = systemVolume
        self.source = source
        self.artworkJPEG = artworkJPEG
        self.updatedAt = updatedAt
    }

    public static let idle = WatchPlaybackSnapshot(
        revision: 0,
        bookID: nil,
        title: "",
        author: "",
        chapterTitle: "",
        playbackState: .idle,
        playbackSpeed: 1,
        skipForwardSeconds: 30,
        skipBackwardSeconds: 15,
        chapterIndex: 0,
        chapterCount: 0,
        chapterElapsed: 0,
        chapterDuration: 0,
        chapterProgress: 0,
        globalCurrentTime: 0,
        globalDuration: 0,
        systemVolume: 0.5,
        source: .remote,
        artworkJPEG: nil
    )
}

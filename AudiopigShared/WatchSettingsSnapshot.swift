//
//  WatchSettingsSnapshot.swift
//  AudiopigShared
//

import Foundation

public struct WatchSettingsSnapshot: Codable, Sendable, Equatable {
    public let artworkSkipGesturesEnabled: Bool
    public let skipForwardSeconds: TimeInterval
    public let skipBackwardSeconds: TimeInterval
    /// Optional to allow older payloads to decode.
    public let speedPresets: [Float]?
    /// Optional to allow older payloads to decode.
    public let playbackTimelineScope: PlaybackTimelineScope?
    /// Optional to allow older payloads to decode.
    public let defaultSpeed: Float?
    /// Optional to allow older payloads to decode.
    public let universalPlaybackSpeedEnabled: Bool?
    /// Optional to allow older payloads to decode.
    public let universalPlaybackSpeed: Float?

    public init(
        artworkSkipGesturesEnabled: Bool,
        skipForwardSeconds: TimeInterval,
        skipBackwardSeconds: TimeInterval,
        speedPresets: [Float]? = nil,
        playbackTimelineScope: PlaybackTimelineScope? = nil,
        defaultSpeed: Float? = nil,
        universalPlaybackSpeedEnabled: Bool? = nil,
        universalPlaybackSpeed: Float? = nil
    ) {
        self.artworkSkipGesturesEnabled = artworkSkipGesturesEnabled
        self.skipForwardSeconds = skipForwardSeconds
        self.skipBackwardSeconds = skipBackwardSeconds
        self.speedPresets = speedPresets
        self.playbackTimelineScope = playbackTimelineScope
        self.defaultSpeed = defaultSpeed
        self.universalPlaybackSpeedEnabled = universalPlaybackSpeedEnabled
        self.universalPlaybackSpeed = universalPlaybackSpeed
    }
}

//
//  WatchPlaybackSource.swift
//  AudiopigShared
//

import Foundation

/// Where playback is driven from. v1 uses `.remote` only; `.local` reserved for on-device books.
public enum WatchPlaybackSource: String, Codable, Sendable {
    case remote
    case local
}

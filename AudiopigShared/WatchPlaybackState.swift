//
//  WatchPlaybackState.swift
//  AudiopigShared
//

import Foundation

/// Transport state mirrored from the iPhone engine for Watch UI.
public enum WatchPlaybackState: Codable, Sendable, Equatable {
    case idle
    case loading
    case playing
    case paused
    case finished
    case failed(message: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case message
    }

    private enum Kind: String, Codable {
        case idle, loading, playing, paused, finished, failed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .idle: self = .idle
        case .loading: self = .loading
        case .playing: self = .playing
        case .paused: self = .paused
        case .finished: self = .finished
        case .failed:
            let message = try container.decode(String.self, forKey: .message)
            self = .failed(message: message)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .idle:
            try container.encode(Kind.idle, forKey: .kind)
        case .loading:
            try container.encode(Kind.loading, forKey: .kind)
        case .playing:
            try container.encode(Kind.playing, forKey: .kind)
        case .paused:
            try container.encode(Kind.paused, forKey: .kind)
        case .finished:
            try container.encode(Kind.finished, forKey: .kind)
        case .failed(let message):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(message, forKey: .message)
        }
    }

    public var isActive: Bool {
        switch self {
        case .playing, .paused, .loading:
            return true
        case .idle, .finished, .failed:
            return false
        }
    }
}

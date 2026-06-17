//
//  WatchLullResult.swift
//  AudiopigShared
//

import Foundation

/// Longest silence / break found in the lull-detection window on iPhone.
public struct WatchLullResult: Codable, Sendable, Equatable {
    /// Global book timeline position where speech resumes after the pause.
    public let endTime: TimeInterval
    /// Duration of the silence span.
    public let duration: TimeInterval

    public init(endTime: TimeInterval, duration: TimeInterval) {
        self.endTime = endTime
        self.duration = duration
    }
}

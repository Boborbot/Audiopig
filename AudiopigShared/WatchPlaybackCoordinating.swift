//
//  WatchPlaybackCoordinating.swift
//  AudiopigShared
//

import Foundation

/// Watch-side abstraction over remote (iPhone) or local (transferred) playback.
@MainActor
public protocol WatchPlaybackCoordinating: AnyObject {
    var snapshot: WatchPlaybackSnapshot? { get }
    var isReachable: Bool { get }
    func send(_ command: WatchCommand) async -> WatchCommandResult
    func setSnapshotHandler(_ handler: @escaping (WatchPlaybackSnapshot) -> Void)
}

public enum WatchSpeedRange {
    public static let min: Float = 0.25
    public static let max: Float = 4.0
    public static let step: Float = 0.05
    /// Crown detent size — 3× coarser than `step` for less sensitive crown control.
    public static let crownStep: Float = step * 3
    /// Default preset buttons shown on the Watch player (and mirrored on iPhone).
    public static let presets: [Float] = [1.0, 1.2, 1.5]
}

public enum WatchTimeFormat {
    public static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

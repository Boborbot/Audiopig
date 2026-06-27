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

public enum WatchVolumeRange {
    /// Matches iOS system output volume granularity (~16 steps).
    public static let step: Float = 1.0 / 16.0
    /// Crown detent size for media controls — 6× finer than `step` so volume changes slowly.
    public static let crownStep: Float = step / 6
    public static let tolerance: Float = step / 2

    public static func normalized(_ volume: Float) -> Float {
        let stepped = (volume / step).rounded() * step
        return min(1, max(0, stepped))
    }
}

public enum WatchSpeedRange {
    public static let min: Float = 0.25
    public static let max: Float = 4.0
    public static let step: Float = 0.05
    /// Crown detent size for the speed panel — 9× coarser than `step` for less sensitive crown control.
    public static let crownStep: Float = step * 9
    /// Default preset buttons shown on the Watch player (and mirrored on iPhone).
    public static let presets: [Float] = [1.0, 1.2, 1.5]

    private static let minStepIndex = 5
    private static let maxStepIndex = 80
    private static let centiPerStep = 5

    /// Snaps `speed` to the nearest 0.05× step within `[min, max]`.
    public static func normalized(_ speed: Float) -> Float {
        speedAtStepIndex(stepIndex(for: speed))
    }

    /// Moves `speed` by `delta` steps of 0.05× each (negative to decrease).
    public static func adjusted(_ speed: Float, byStepCount delta: Int) -> Float {
        speedAtStepIndex(stepIndex(for: speed) + delta)
    }

    /// Longest display label in `[min, max]` — sizes the player speed pill so the value never wraps.
    public static var widestLabel: String {
        var widest = ""
        for index in minStepIndex...maxStepIndex {
            let label = formatLabel(speedAtStepIndex(index))
            if label.count > widest.count {
                widest = label
            }
        }
        return widest
    }

    /// Display label: up to two decimals, trailing zeros omitted (e.g. `1×`, `1.1×`, `1.15×`).
    public static func formatLabel(_ speed: Float) -> String {
        let centi = stepIndex(for: speed) * centiPerStep
        let whole = centi / 100
        let fraction = centi % 100
        if fraction == 0 {
            return "\(whole)×"
        }
        if fraction % 10 == 0 {
            return "\(whole).\(fraction / 10)×"
        }
        let tenths = fraction / 10
        let hundredths = fraction % 10
        return "\(whole).\(tenths)\(hundredths)×"
    }

    private static func stepIndex(for speed: Float) -> Int {
        let clamped = Swift.min(Swift.max(speed, min), max)
        let index = Int((Double(clamped) / Double(step)).rounded())
        return Swift.min(Swift.max(index, minStepIndex), maxStepIndex)
    }

    private static func speedAtStepIndex(_ index: Int) -> Float {
        let clamped = Swift.min(Swift.max(index, minStepIndex), maxStepIndex)
        return Float(clamped * centiPerStep) / 100
    }
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

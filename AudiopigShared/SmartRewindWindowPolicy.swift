//
//  SmartRewindWindowPolicy.swift
//  AudiopigShared
//

import Foundation

public enum SmartRewindScopeKind: Sendable, Equatable {
    case far
    case near
}

public struct SmartRewindWindowOffsets: Equatable, Sendable {
    public var startOffset: TimeInterval
    public var endOffset: TimeInterval

    public init(startOffset: TimeInterval, endOffset: TimeInterval) {
        self.startOffset = startOffset
        self.endOffset = endOffset
    }
}

public enum SmartRewindWindowPolicy {
    private static let farMinimumGap: TimeInterval = 30
    private static let nearMinimumGap: TimeInterval = 5

    public static func minimumGap(for scope: SmartRewindScopeKind) -> TimeInterval {
        scope == .far ? farMinimumGap : nearMinimumGap
    }

    public static func startOffsetBounds(for scope: SmartRewindScopeKind) -> ClosedRange<TimeInterval> {
        switch scope {
        case .far:
            return 5 * 60 ... 60 * 60
        case .near:
            return 30 ... 15 * 60
        }
    }

    public static func endOffsetBounds(for scope: SmartRewindScopeKind) -> ClosedRange<TimeInterval> {
        switch scope {
        case .far:
            return 60 ... 30 * 60
        case .near:
            return 0 ... 5 * 60
        }
    }

    public static func startSliderStep(for scope: SmartRewindScopeKind) -> TimeInterval {
        scope == .far ? 60 : 15
    }

    public static func endSliderStep(for scope: SmartRewindScopeKind) -> TimeInterval {
        scope == .far ? 60 : 5
    }

    public static func clampedStartOffset(
        _ start: TimeInterval,
        end: TimeInterval,
        for scope: SmartRewindScopeKind
    ) -> TimeInterval {
        let bounds = startOffsetBounds(for: scope)
        let gap = minimumGap(for: scope)
        let lowerBound = max(bounds.lowerBound, end + gap)
        let upperBound = bounds.upperBound
        guard lowerBound <= upperBound else { return bounds.lowerBound }
        return min(max(start, lowerBound), upperBound)
    }

    public static func clampedEndOffset(
        _ end: TimeInterval,
        start: TimeInterval,
        for scope: SmartRewindScopeKind
    ) -> TimeInterval {
        let bounds = endOffsetBounds(for: scope)
        let gap = minimumGap(for: scope)
        let lowerBound = bounds.lowerBound
        let upperBound = min(bounds.upperBound, start - gap)
        guard lowerBound <= upperBound else { return bounds.lowerBound }
        return min(max(end, lowerBound), upperBound)
    }

    public static func clampedOffsets(
        _ offsets: SmartRewindWindowOffsets,
        for scope: SmartRewindScopeKind
    ) -> SmartRewindWindowOffsets {
        let startBounds = startOffsetBounds(for: scope)
        var start = min(max(offsets.startOffset, startBounds.lowerBound), startBounds.upperBound)
        var end = clampedEndOffset(offsets.endOffset, start: start, for: scope)
        start = clampedStartOffset(start, end: end, for: scope)
        end = clampedEndOffset(end, start: start, for: scope)
        return SmartRewindWindowOffsets(startOffset: start, endOffset: end)
    }

    public static func playbackWindow(
        currentTime: TimeInterval,
        offsets: SmartRewindWindowOffsets
    ) -> (from: TimeInterval, to: TimeInterval) {
        let from = max(0, currentTime - offsets.startOffset)
        let to = max(from + 1, currentTime - offsets.endOffset)
        return (from, to)
    }

    public static func formatOffsetLabel(_ seconds: TimeInterval, allowsNow: Bool = false) -> String {
        if allowsNow, seconds <= 0 {
            return "Now"
        }
        if seconds >= 60 {
            let minutes = Int(seconds / 60)
            return minutes == 1 ? "1 min ago" : "\(minutes) min ago"
        }
        return "\(Int(seconds))s ago"
    }
}

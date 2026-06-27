//
//  SubtitleCueResolver.swift
//  AudiopigShared
//

import Foundation

public struct SubtitleCueWindow: Sendable, Equatable {
    public let activeIndex: Int?
    public let cues: [SubtitleCueTiming]

    public init(activeIndex: Int?, cues: [SubtitleCueTiming]) {
        self.activeIndex = activeIndex
        self.cues = cues
    }
}

public enum SubtitleCueResolver {

    /// True when a saved cue is active at `globalTime` (display layer only).
    public static func hasActiveCue(
        at globalTime: TimeInterval,
        cues: [SubtitleCueTiming]
    ) -> Bool {
        resolveActiveCueIndex(at: globalTime, cues: cues) != nil
    }

    /// Index of the cue the overlay should show — holds the previous line through inter-cue gaps.
    public static func resolveDisplayCueIndex(
        at globalTime: TimeInterval,
        cues: [SubtitleCueTiming]
    ) -> Int? {
        if let active = resolveActiveCueIndex(at: globalTime, cues: cues) {
            return active
        }
        guard !cues.isEmpty else { return nil }

        var low = 0
        var high = cues.count - 1
        var result: Int?

        while low <= high {
            let mid = (low + high) / 2
            if cues[mid].startTime <= globalTime {
                result = mid
                low = mid + 1
            } else {
                high = mid - 1
            }
        }

        return result
    }

    /// Returns the index of the cue active at `globalTime`, if any.
    public static func resolveActiveCueIndex(
        at globalTime: TimeInterval,
        cues: [SubtitleCueTiming]
    ) -> Int? {
        guard !cues.isEmpty else { return nil }

        var low = 0
        var high = cues.count - 1
        var candidate: Int?

        while low <= high {
            let mid = (low + high) / 2
            let cue = cues[mid]
            if globalTime < cue.startTime {
                high = mid - 1
            } else if globalTime >= cue.endTime {
                low = mid + 1
            } else {
                candidate = mid
                break
            }
        }

        return candidate
    }

    /// Returns up to `radius` cues before and after the display cue for scrolling display.
    /// Holds the previous line visible through inter-cue gaps.
    public static func visibleWindow(
        at globalTime: TimeInterval,
        cues: [SubtitleCueTiming],
        radius: Int = 17
    ) -> SubtitleCueWindow {
        guard !cues.isEmpty else {
            return SubtitleCueWindow(activeIndex: nil, cues: [])
        }

        guard let displayIndex = resolveDisplayCueIndex(at: globalTime, cues: cues) else {
            return SubtitleCueWindow(activeIndex: nil, cues: [])
        }

        let lower = max(0, displayIndex - radius)
        let upper = min(cues.count - 1, displayIndex + radius)
        let slice = Array(cues[lower...upper])
        let adjustedActive = displayIndex - lower
        return SubtitleCueWindow(activeIndex: adjustedActive, cues: slice)
    }

    /// Lines removed from the top when a forward-scrolling cue window slides.
    public static func slidingWindowTopRemoval(old: [String], new: [String]) -> Int {
        guard !old.isEmpty, !new.isEmpty else { return 0 }
        if old.first == new.first { return 0 }
        if let firstNew = new.first, let oldIndex = old.firstIndex(of: firstNew) {
            return oldIndex
        }
        return 0
    }

    /// Lines inserted at the top when a backward-scrolling cue window slides.
    public static func slidingWindowTopInsertion(old: [String], new: [String]) -> Int {
        guard !old.isEmpty, !new.isEmpty else { return 0 }
        if old.first == new.first { return 0 }
        if let firstOld = old.first, let newIndex = new.firstIndex(of: firstOld) {
            return newIndex
        }
        return 0
    }

    /// True when at least one cue overlaps the given window.
    public static func hasCoverage(
        in window: SubtitleTimeWindow,
        cues: [SubtitleCueTiming]
    ) -> Bool {
        cues.contains { cue in
            cue.startTime < window.globalEnd && cue.endTime > window.globalStart
        }
    }
}

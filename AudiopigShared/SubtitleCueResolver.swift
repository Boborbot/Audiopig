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

    /// Returns up to `radius` cues before and after the active cue for scrolling display.
    public static func visibleWindow(
        at globalTime: TimeInterval,
        cues: [SubtitleCueTiming],
        radius: Int = 8
    ) -> SubtitleCueWindow {
        guard !cues.isEmpty else {
            return SubtitleCueWindow(activeIndex: nil, cues: [])
        }

        guard let active = resolveActiveCueIndex(at: globalTime, cues: cues) else {
            return SubtitleCueWindow(activeIndex: nil, cues: [])
        }

        let lower = max(0, active - radius)
        let upper = min(cues.count - 1, active + radius)
        let slice = Array(cues[lower...upper])
        let adjustedActive = active - lower
        return SubtitleCueWindow(activeIndex: adjustedActive, cues: slice)
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

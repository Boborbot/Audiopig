//
//  SubtitleWindowPlanner.swift
//  AudiopigShared
//
//  Subtitle pipeline: see docs/subtitles-architecture.md and .cursor/rules/subtitles.mdc
//

import Foundation

public enum SubtitleWindowPlanner {

    public static let defaultWindowDuration: TimeInterval = 10 * 60
    public static let playheadLeadIn: TimeInterval = 2 * 60

    /// First window to transcribe when the user opens subtitles near the playhead.
    public static func initialNearPlayheadWindow(
        playhead: TimeInterval,
        bookDuration: TimeInterval,
        windowDuration: TimeInterval = defaultWindowDuration
    ) -> SubtitleTimeWindow {
        let start = max(0, playhead - playheadLeadIn)
        let end = min(bookDuration, start + windowDuration)
        return SubtitleTimeWindow(globalStart: start, globalEnd: end)
    }

    /// Splits the full book into fixed windows for whole-book transcription.
    public static func wholeBookWindows(
        bookDuration: TimeInterval,
        windowDuration: TimeInterval = defaultWindowDuration
    ) -> [SubtitleTimeWindow] {
        guard bookDuration > 0, windowDuration > 0 else { return [] }

        var windows: [SubtitleTimeWindow] = []
        var start: TimeInterval = 0
        while start < bookDuration {
            let end = min(bookDuration, start + windowDuration)
            windows.append(SubtitleTimeWindow(globalStart: start, globalEnd: end))
            start = end
        }
        return windows
    }

    /// Fixed windows from the section containing `playhead` through the end of the book.
    /// Sections entirely behind the playhead are omitted.
    public static func windowsFromCurrentSection(
        playhead: TimeInterval,
        bookDuration: TimeInterval,
        windowDuration: TimeInterval = defaultWindowDuration
    ) -> [SubtitleTimeWindow] {
        let windows = wholeBookWindows(bookDuration: bookDuration, windowDuration: windowDuration)
        let clamped = max(0, playhead)
        guard let startIndex = windows.firstIndex(where: { window in
            window.contains(clamped) || window.globalStart >= clamped
        }) else {
            return []
        }
        return Array(windows[startIndex...])
    }
}

//
//  AudiobookProgressFormatter.swift
//  Audiopig
//

import Foundation

/// Pure, stateless presentation-layer helpers for displaying audiobook progress.
/// Never import SwiftUI or SwiftData here.
enum AudiobookProgressFormatter {

    // MARK: - Progress Ratio

    /// Returns a value in [0, 1] representing how much of the book has been played.
    static func progress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        guard duration > 0 else { return 0 }
        return max(0, min(1, currentTime / duration))
    }

    // MARK: - Formatted Strings

    /// E.g. "2 hr 14 min left · 11 hr 32 min total"
    /// Edge cases: unstarted → "Not started · X total", finished → "Finished · X total"
    static func progressText(currentTime: TimeInterval, duration: TimeInterval) -> String {
        guard duration > 0 else { return "Unknown duration" }

        let totalText = shortDuration(duration)

        if currentTime <= 0 {
            return "Not started · \(totalText)"
        }

        let remaining = duration - currentTime
        if remaining <= 0 {
            return "Finished · \(totalText)"
        }

        return "\(shortDuration(remaining)) left · \(totalText)"
    }

    // MARK: - Private

    /// "11 hr 32 min", "45 min", "< 1 min"
    private static func shortDuration(_ interval: TimeInterval) -> String {
        let totalSeconds = Int(interval)
        let hours   = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 && minutes > 0 {
            return "\(hours) hr \(minutes) min"
        } else if hours > 0 {
            return "\(hours) hr"
        } else if minutes > 0 {
            return "\(minutes) min"
        } else {
            return "< 1 min"
        }
    }
}

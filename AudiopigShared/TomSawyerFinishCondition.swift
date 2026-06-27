//
//  TomSawyerFinishCondition.swift
//  AudiopigShared
//
//  Hoid secret achievement (agent term — see .cursor/rules/secret-achievements.mdc):
//  finish Tom Sawyer by Mark Twain (title and author must both match, typo-tolerant)
//  after genuinely listening to ≥75%. Unlocks the Pig Sawyer icon.
//

import Foundation

public enum TomSawyerFinishCondition {

    public static let listenedThreshold = 0.75

    private static let authorSignals: [String] = [
        "mark twain",
        "m twain",
        "samuel clemens",
        "samuel l clemens",
        "samuel langhorne clemens",
        "clemens mark twain",
        "twain mark",
    ]

    private static let titleSignals: [String] = [
        "tom sawyer",
        "tom sawer",
    ]

    public static func isSatisfied(
        title: String,
        author: String,
        listenedSeconds: TimeInterval,
        totalSeconds: TimeInterval
    ) -> Bool {
        guard totalSeconds > 0 else { return false }
        let fraction = listenedSeconds / totalSeconds
        guard fraction >= listenedThreshold else { return false }
        return matchesTomSawyerMetadata(title: title, author: author)
    }

    public static func matchesTomSawyerMetadata(title: String, author: String) -> Bool {
        let normalizedTitle = normalize(title)
        let normalizedAuthor = normalize(author)

        let titleMatches = titleSignals.contains { normalizedTitle.contains($0) }
        let authorMatches = authorSignals.contains { normalizedAuthor.contains($0) }

        return titleMatches && authorMatches
    }

    /// Lowercases, folds punctuation to spaces, and collapses repeated whitespace.
    static func normalize(_ string: String) -> String {
        let lowered = string.lowercased()
        let punctuation = CharacterSet.punctuationCharacters.union(.symbols)
        let spaced = lowered.unicodeScalars.map { scalar -> String in
            punctuation.contains(scalar) ? " " : String(scalar)
        }.joined()
        return spaced
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

//
//  MiddleEarthFinishCondition.swift
//  AudiopigShared
//
//  Hoid secret achievement (agent term — see .cursor/rules/secret-achievements.mdc):
//  finish a Tolkien/Middle-earth audiobook (title must match) after genuinely listening to ≥75%.
//  Unlocks the Pigaladriel icon.
//

import Foundation

public enum MiddleEarthFinishCondition {

    public static let listenedThreshold = 0.75

    /// Author tokens — pair with a weak title signal; never sufficient alone.
    private static let authorSignals: [String] = [
        "tolkien",
        "tolkein",
        "j r r",
        "jrr",
        "john ronald reuel",
    ]

    /// Specific work titles — sufficient on their own.
    private static let strongTitleSignals: [String] = [
        "lord of the rings",
        "lotr",
        "silmarillion",
        "silmarilion",
        "the hobbit",
        "fellowship of the ring",
        "two towers",
        "return of the king",
    ]

    /// Ambiguous fragments — only count when the author also matches.
    private static let weakTitleSignals: [String] = [
        "hobbit",
        "fellowship",
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
        return matchesMiddleEarthMetadata(title: title, author: author)
    }

    public static func matchesMiddleEarthMetadata(title: String, author: String) -> Bool {
        let normalizedTitle = normalize(title)
        let normalizedAuthor = normalize(author)

        let authorMatches = authorSignals.contains { normalizedAuthor.contains($0) }

        if strongTitleSignals.contains(where: { normalizedTitle.contains($0) }) {
            return true
        }

        if authorMatches,
           weakTitleSignals.contains(where: { normalizedTitle.contains($0) }) {
            return true
        }

        return false
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

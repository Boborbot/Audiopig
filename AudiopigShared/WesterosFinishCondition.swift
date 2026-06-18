//
//  WesterosFinishCondition.swift
//  AudiopigShared
//
//  Hoid secret achievement (agent term — see .cursor/rules/secret-achievements.mdc):
//  finish one of the main five ASOIAF books (title must match) after genuinely listening to ≥75%.
//

import Foundation

public enum WesterosFinishCondition {

    public static let listenedThreshold = 0.75

    /// Author tokens — pair with a weak title signal; never sufficient alone.
    private static let authorSignals: [String] = [
        "george r r martin",
        "g r r martin",
        "grrm",
        "george rr martin",
        "martin george r r",
        "martin george",
    ]

    /// Main five ASOIAF novels and series names — sufficient on their own.
    private static let strongTitleSignals: [String] = [
        "a game of thrones",
        "game of thrones",
        "a clash of kings",
        "clash of kings",
        "a storm of swords",
        "storm of swords",
        "a feast for crows",
        "feast for crows",
        "a dance with dragons",
        "dance with dragons",
        "a song of ice and fire",
        "song of ice and fire",
        "asoiaf",
    ]

    /// Ambiguous fragments — only count when the author also matches.
    private static let weakTitleSignals: [String] = [
        "thrones",
        "westeros",
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
        return matchesWesterosMetadata(title: title, author: author)
    }

    public static func matchesWesterosMetadata(title: String, author: String) -> Bool {
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

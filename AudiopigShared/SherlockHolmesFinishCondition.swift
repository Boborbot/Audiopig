//
//  SherlockHolmesFinishCondition.swift
//  AudiopigShared
//
//  Hoid secret achievement (agent term — see .cursor/rules/secret-achievements.mdc):
//  finish an audiobook whose title contains "Sherlock Holmes", or whose author is
//  Arthur Conan Doyle (typo-tolerant), after genuinely listening to ≥75%.
//  Unlocks the Sher Pig icon.
//

import Foundation

public enum SherlockHolmesFinishCondition {

    public static let listenedThreshold = 0.75

    /// Author tokens — sufficient on their own; never paired with weak title signals.
    private static let authorSignals: [String] = [
        "arthur conan doyle",
        "artur conan doyle",
        "a conan doyle",
        "sir arthur conan doyle",
        "conan doyle",
        "doyle arthur conan",
    ]

    /// Only "Sherlock Holmes" in the title counts — no subtitle-only or weak fragments.
    private static let strongTitleSignals: [String] = [
        "sherlock holmes",
        "sherlock holms",
        "sherlock homes",
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
        return matchesSherlockHolmesMetadata(title: title, author: author)
    }

    public static func matchesSherlockHolmesMetadata(title: String, author: String) -> Bool {
        let normalizedTitle = normalize(title)
        let normalizedAuthor = normalize(author)

        if strongTitleSignals.contains(where: { normalizedTitle.contains($0) }) {
            return true
        }

        if authorSignals.contains(where: { normalizedAuthor.contains($0) }) {
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

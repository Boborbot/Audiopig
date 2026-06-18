//
//  HogwartsFinishCondition.swift
//  AudiopigShared
//
//  Hoid secret achievement (agent term — see .cursor/rules/secret-achievements.mdc):
//  finish one of the main seven Harry Potter novels (title must match) after
//  genuinely listening to ≥75%. Unlocks The Pig Who Lived icon.
//

import Foundation

public enum HogwartsFinishCondition {

    public static let listenedThreshold = 0.75

    /// Author tokens — pair with a weak title signal; never sufficient alone.
    private static let authorSignals: [String] = [
        "j k rowling",
        "jk rowling",
        "joanne rowling",
        "rowling j k",
    ]

    /// Main seven novels — sufficient on their own (UK + US stone title).
    private static let strongTitleSignals: [String] = [
        "harry potter and the philosophers stone",
        "harry potter and the sorcerers stone",
        "philosophers stone",
        "philosopher s stone",
        "sorcerers stone",
        "sorcerer s stone",
        "harry potter and the chamber of secrets",
        "chamber of secrets",
        "harry potter and the prisoner of azkaban",
        "prisoner of azkaban",
        "harry potter and the goblet of fire",
        "goblet of fire",
        "harry potter and the order of the phoenix",
        "order of the phoenix",
        "harry potter and the half blood prince",
        "half blood prince",
        "harry potter and the deathly hallows",
        "deathly hallows",
    ]

    /// Ambiguous fragments — only count when the author also matches.
    private static let weakTitleSignals: [String] = [
        "azkaban",
        "hogwarts",
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
        return matchesHogwartsMetadata(title: title, author: author)
    }

    public static func matchesHogwartsMetadata(title: String, author: String) -> Bool {
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

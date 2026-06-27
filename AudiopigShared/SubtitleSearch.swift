//
//  SubtitleSearch.swift
//  AudiopigShared
//

import Foundation

public enum SubtitleSearch {

    public static let defaultResultLimit = 150

    public struct Result: Sendable, Equatable {
        public let matches: [SubtitleCueTiming]
        public let totalCount: Int

        public init(matches: [SubtitleCueTiming], totalCount: Int) {
            self.matches = matches
            self.totalCount = totalCount
        }
    }

    /// Returns cues whose text matches the query, in timeline order.
    /// Single-line matches return that cue. Matches spanning consecutive lines return the first line only.
    public static func search(
        query: String,
        in cues: [SubtitleCueTiming],
        limit: Int = defaultResultLimit
    ) -> Result {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Result(matches: [], totalCount: 0)
        }

        var matches: [SubtitleCueTiming] = []
        var totalCount = 0

        for index in cues.indices {
            let cue = cues[index]
            if cue.text.localizedStandardContains(trimmed) {
                recordMatch(cue, into: &matches, totalCount: &totalCount, limit: limit)
                continue
            }

            guard index + 1 < cues.count else { continue }
            let nextCue = cues[index + 1]
            let pairText = cue.text + " " + nextCue.text
            guard pairText.localizedStandardContains(trimmed),
                  !nextCue.text.localizedStandardContains(trimmed) else { continue }

            recordMatch(cue, into: &matches, totalCount: &totalCount, limit: limit)
        }

        return Result(matches: matches, totalCount: totalCount)
    }

    private static func recordMatch(
        _ cue: SubtitleCueTiming,
        into matches: inout [SubtitleCueTiming],
        totalCount: inout Int,
        limit: Int
    ) {
        totalCount += 1
        if matches.count < limit {
            matches.append(cue)
        }
    }

    /// Returns cues whose text matches the query, in timeline order.
    public static func matchingCues(
        query: String,
        in cues: [SubtitleCueTiming],
        limit: Int = defaultResultLimit
    ) -> [SubtitleCueTiming] {
        search(query: query, in: cues, limit: limit).matches
    }
}

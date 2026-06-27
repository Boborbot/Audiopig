//
//  SubtitleLineGrouper.swift
//  AudiopigShared
//

import Foundation

public enum SubtitleLineGrouper {

    public static let defaultMaxCharacters = 108
    public static let defaultPauseGap: TimeInterval = 0.4

    /// Merges word-level runs into display lines suitable for SwiftData storage.
    public static func groupIntoLines(
        _ runs: [TimedTextRun],
        maxCharacters: Int = defaultMaxCharacters,
        pauseGap: TimeInterval = defaultPauseGap,
        startingOrderIndex: Int = 0
    ) -> [SubtitleCueTiming] {
        guard !runs.isEmpty else { return [] }

        var lines: [SubtitleCueTiming] = []
        var currentRuns: [TimedTextRun] = []
        var orderIndex = startingOrderIndex

        func flushLine(_ runs: [TimedTextRun]) {
            let text = joinedText(runs)
            guard !text.isEmpty,
                  let first = runs.first,
                  let last = runs.last,
                  last.endTime > first.startTime else { return }
            lines.append(
                SubtitleCueTiming(
                    startTime: first.startTime,
                    endTime: last.endTime,
                    text: text,
                    orderIndex: orderIndex
                )
            )
            orderIndex += 1
        }

        for run in runs {
            let trimmedRun = run.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRun.isEmpty else { continue }

            let normalized = TimedTextRun(
                text: trimmedRun,
                startTime: run.startTime,
                endTime: run.endTime
            )

            if currentRuns.isEmpty {
                currentRuns = [normalized]
                continue
            }

            let gap = normalized.startTime - currentRuns[currentRuns.count - 1].endTime
            let proposed = joinedText(currentRuns) + " " + trimmedRun
            let exceedsLength = proposed.count > maxCharacters
            let exceedsPause = gap > pauseGap

            if exceedsPause {
                flushLine(currentRuns)
                currentRuns = [normalized]
            } else if exceedsLength {
                if let breakIndex = preferredBreakIndex(in: currentRuns, maxCharacters: maxCharacters) {
                    let firstSegment = Array(currentRuns[0...breakIndex])
                    flushLine(firstSegment)
                    currentRuns = Array(currentRuns[(breakIndex + 1)...])
                } else {
                    flushLine(currentRuns)
                    currentRuns = []
                }
                currentRuns.append(normalized)
            } else {
                currentRuns.append(normalized)
            }
        }

        if !currentRuns.isEmpty {
            flushLine(currentRuns)
        }

        return lines
    }

    private static func joinedText(_ runs: [TimedTextRun]) -> String {
        runs.map(\.text).joined(separator: " ")
    }

    /// Rightmost run index after which a line may break within `maxCharacters`, preferring sentence ends then commas.
    private static func preferredBreakIndex(in runs: [TimedTextRun], maxCharacters: Int) -> Int? {
        var bestSentence: Int?
        var bestComma: Int?

        for index in runs.indices {
            let segment = Array(runs[0...index])
            guard joinedText(segment).count <= maxCharacters else { continue }

            if endsSentence(runs[index].text) {
                bestSentence = index
            }
            if endsWithComma(runs[index].text) {
                bestComma = index
            }
        }

        return bestSentence ?? bestComma
    }

    private static func endsSentence(_ text: String) -> Bool {
        guard let last = text.last else { return false }
        return last == "." || last == "?" || last == "!"
    }

    private static func endsWithComma(_ text: String) -> Bool {
        text.hasSuffix(",")
    }
}

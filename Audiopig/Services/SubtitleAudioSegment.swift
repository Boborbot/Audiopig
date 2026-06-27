//
//  SubtitleAudioSegment.swift
//  Audiopig
//

import Foundation

/// Maps a global timeline window to one or more on-disk audio file slices.
struct SubtitleAudioSegment: Sendable, Equatable {
    let fileURL: URL
    let fileLocalStart: TimeInterval
    let fileLocalEnd: TimeInterval
    let globalOffset: TimeInterval
}

enum SubtitleAudioSegmentPlanner {

    static func segments(
        for window: SubtitleTimeWindow,
        chapters: [ResolvedChapter]
    ) -> [SubtitleAudioSegment] {
        guard window.duration > 0, !chapters.isEmpty else { return [] }

        var fileGlobalOffsets: [URL: TimeInterval] = [:]
        for chapter in chapters {
            let current = fileGlobalOffsets[chapter.fileURL]
            if current == nil || chapter.startTime < current! {
                fileGlobalOffsets[chapter.fileURL] = chapter.startTime
            }
        }

        let overlapping = chapters.filter {
            $0.startTime < window.globalEnd && $0.startTime + $0.duration > window.globalStart
        }

        var segments: [SubtitleAudioSegment] = []
        for chapter in overlapping {
            let globalOffset = fileGlobalOffsets[chapter.fileURL] ?? chapter.startTime
            let chapterGlobalStart = chapter.startTime
            let chapterGlobalEnd = chapter.startTime + chapter.duration

            let sliceStart = max(window.globalStart, chapterGlobalStart)
            let sliceEnd = min(window.globalEnd, chapterGlobalEnd)
            guard sliceEnd > sliceStart else { continue }

            let fileLocalStart = max(0, sliceStart - globalOffset)
            let fileLocalEnd = sliceEnd - globalOffset
            guard fileLocalEnd > fileLocalStart else { continue }

            segments.append(
                SubtitleAudioSegment(
                    fileURL: chapter.fileURL,
                    fileLocalStart: fileLocalStart,
                    fileLocalEnd: fileLocalEnd,
                    globalOffset: globalOffset
                )
            )
        }

        return segments.sorted { $0.fileLocalStart < $1.fileLocalStart }
    }
}

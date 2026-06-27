//
//  SubtitleStore.swift
//  Audiopig
//

import Foundation
import SwiftData

@MainActor
final class SubtitleStore: SubtitleStoreProtocol {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func sortedCues(for audiobookID: UUID) throws -> [SubtitleCueTiming] {
        let descriptor = FetchDescriptor<SubtitleCue>(
            predicate: #Predicate { $0.audiobook?.id == audiobookID },
            sortBy: [SortDescriptor(\.startTime), SortDescriptor(\.orderIndex)]
        )
        return try modelContext.fetch(descriptor).map(\.timing)
    }

    func sortedSegments(for audiobookID: UUID) throws -> [SubtitleTranscriptionSegmentTiming] {
        let descriptor = FetchDescriptor<SubtitleTranscriptionSegment>(
            predicate: #Predicate { $0.audiobook?.id == audiobookID },
            sortBy: [SortDescriptor(\.startTime)]
        )
        return SubtitleSegmentPlanner.merged(try modelContext.fetch(descriptor).map(\.timing))
    }

    func insertCues(_ cues: [SubtitleCueTiming], audiobook: Audiobook) throws {
        let existing = try sortedCues(for: audiobook.id)
        let novel = cues.filter { cue in
            !existing.contains { saved in
                abs(saved.startTime - cue.startTime) < 0.25
                    && saved.text == cue.text
            }
        }
        guard !novel.isEmpty else { return }

        let existingCount = audiobook.subtitleCues.count
        for (offset, cue) in novel.enumerated() {
            let model = SubtitleCue(
                startTime: cue.startTime,
                endTime: cue.endTime,
                text: cue.text,
                orderIndex: existingCount + offset,
                audiobook: audiobook
            )
            modelContext.insert(model)
        }
        try modelContext.save()
    }

    func insertSegment(window: SubtitleTimeWindow, audiobook: Audiobook) throws {
        let overlapping = audiobook.subtitleTranscriptionSegments.filter { segment in
            segment.startTime < window.globalEnd && segment.endTime > window.globalStart
        }
        for segment in overlapping {
            modelContext.delete(segment)
        }
        audiobook.subtitleTranscriptionSegments.removeAll { segment in
            segment.startTime < window.globalEnd && segment.endTime > window.globalStart
        }

        let model = SubtitleTranscriptionSegment(
            startTime: window.globalStart,
            endTime: window.globalEnd,
            audiobook: audiobook
        )
        modelContext.insert(model)
        try modelContext.save()
    }

    func insertInferredSegments(
        _ segments: [SubtitleTranscriptionSegmentTiming],
        audiobook: Audiobook
    ) throws {
        guard !segments.isEmpty else { return }

        for segment in segments {
            let window = SubtitleTimeWindow(globalStart: segment.startTime, globalEnd: segment.endTime)
            try insertSegment(window: window, audiobook: audiobook)
        }
    }

    func deleteAllCues(for audiobook: Audiobook) throws {
        let cues = audiobook.subtitleCues
        for cue in cues {
            modelContext.delete(cue)
        }
        audiobook.subtitleCues.removeAll()
        try modelContext.save()
    }

    func deleteAllSegments(for audiobook: Audiobook) throws {
        let segments = audiobook.subtitleTranscriptionSegments
        for segment in segments {
            modelContext.delete(segment)
        }
        audiobook.subtitleTranscriptionSegments.removeAll()
        try modelContext.save()
    }
}

//
//  SubtitleStoreProtocol.swift
//  Audiopig
//

import Foundation

protocol SubtitleStoreProtocol: Sendable {
    func sortedCues(for audiobookID: UUID) throws -> [SubtitleCueTiming]
    func sortedSegments(for audiobookID: UUID) throws -> [SubtitleTranscriptionSegmentTiming]
    func insertCues(_ cues: [SubtitleCueTiming], audiobook: Audiobook) throws
    func insertSegment(window: SubtitleTimeWindow, audiobook: Audiobook) throws
    func insertInferredSegments(_ segments: [SubtitleTranscriptionSegmentTiming], audiobook: Audiobook) throws
    func deleteAllCues(for audiobook: Audiobook) throws
    func deleteAllSegments(for audiobook: Audiobook) throws
}

//
//  AudiobookFingerprint.swift
//  AudiopigShared
//

import Foundation

/// Identifies an audiobook file for duplicate detection during import.
struct AudiobookFingerprint: Equatable, Sendable, Hashable {
    let normalizedFileName: String
    let fileSize: Int64
    let duration: TimeInterval

    static let durationTolerance: TimeInterval = 1.0

    init(normalizedFileName: String, fileSize: Int64, duration: TimeInterval) {
        self.normalizedFileName = normalizedFileName.lowercased()
        self.fileSize = fileSize
        self.duration = duration
    }

    func matches(_ other: AudiobookFingerprint) -> Bool {
        normalizedFileName == other.normalizedFileName
            && fileSize == other.fileSize
            && abs(duration - other.duration) <= Self.durationTolerance
    }
}

struct LibraryImportFailure: Equatable, Sendable {
    let name: String
    let reason: String
}

struct LibraryImportResult: Equatable, Sendable {
    var importedCount: Int
    var skippedDuplicateCount: Int
    var failed: [LibraryImportFailure]

    static let empty = LibraryImportResult(importedCount: 0, skippedDuplicateCount: 0, failed: [])

    var hasFailures: Bool { !failed.isEmpty }
    var totalProcessed: Int { importedCount + skippedDuplicateCount + failed.count }
}

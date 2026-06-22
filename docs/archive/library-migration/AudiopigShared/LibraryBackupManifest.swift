//
//  LibraryBackupManifest.swift
//  AudiopigShared
//

import Foundation

// MARK: - Manifest v1

struct LibraryBackupManifest: Codable, Equatable, Sendable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let exportedAt: Date
    let books: [LibraryBackupBookEntry]
    let folders: [LibraryBackupFolderEntry]

    init(
        formatVersion: Int = Self.currentFormatVersion,
        exportedAt: Date = .now,
        books: [LibraryBackupBookEntry],
        folders: [LibraryBackupFolderEntry]
    ) {
        self.formatVersion = formatVersion
        self.exportedAt = exportedAt
        self.books = books
        self.folders = folders
    }
}

struct LibraryBackupBookEntry: Codable, Equatable, Sendable, Identifiable {
    var id: String { fingerprint.stableID }
    let fingerprint: LibraryBackupFingerprint
    let title: String
    let author: String
    let currentPlaybackTime: TimeInterval
    let lastPlaybackSpeed: Float?
    let lastPlayedAt: Date?
    let isManuallyFinished: Bool
    let bookmarks: [LibraryBackupBookmarkEntry]
}

struct LibraryBackupFingerprint: Codable, Equatable, Sendable, Hashable {
    let fileName: String
    let fileSize: Int64
    let duration: TimeInterval

    var stableID: String {
        "\(fileName.lowercased())|\(fileSize)|\(Int(duration.rounded()))"
    }

    func toAudiobookFingerprint() -> AudiobookFingerprint {
        AudiobookFingerprint(
            normalizedFileName: fileName,
            fileSize: fileSize,
            duration: duration
        )
    }

    init(fileName: String, fileSize: Int64, duration: TimeInterval) {
        self.fileName = fileName
        self.fileSize = fileSize
        self.duration = duration
    }

    init(audiobookFingerprint: AudiobookFingerprint) {
        self.fileName = audiobookFingerprint.normalizedFileName
        self.fileSize = audiobookFingerprint.fileSize
        self.duration = audiobookFingerprint.duration
    }
}

struct LibraryBackupBookmarkEntry: Codable, Equatable, Sendable {
    let title: String
    let note: String
    let timestamp: TimeInterval
}

struct LibraryBackupFolderEntry: Codable, Equatable, Sendable {
    let title: String
    let bookFingerprints: [LibraryBackupFingerprint]
}

// MARK: - Apply result

struct LibraryBackupApplyResult: Equatable, Sendable {
    var restoredBooks: Int
    var unmatchedEntries: Int
    var foldersApplied: Int

    static let empty = LibraryBackupApplyResult(restoredBooks: 0, unmatchedEntries: 0, foldersApplied: 0)
}

// MARK: - Codec

enum LibraryBackupManifestCodec {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encode(_ manifest: LibraryBackupManifest) throws -> Data {
        try encoder.encode(manifest)
    }

    static func decode(from data: Data) throws -> LibraryBackupManifest {
        let manifest = try decoder.decode(LibraryBackupManifest.self, from: data)
        guard manifest.formatVersion == LibraryBackupManifest.currentFormatVersion else {
            throw LibraryBackupManifestError.unsupportedFormatVersion(manifest.formatVersion)
        }
        return manifest
    }

    static func decode(from url: URL) throws -> LibraryBackupManifest {
        let data = try Data(contentsOf: url)
        return try decode(from: data)
    }
}

enum LibraryBackupManifestError: Error, Equatable {
    case unsupportedFormatVersion(Int)
    case invalidData
}

// MARK: - Merge policy

enum LibraryBackupMergePolicy {
    /// Restores progress without moving the playhead backward.
    static func mergedPlaybackTime(existing: TimeInterval, imported: TimeInterval) -> TimeInterval {
        max(existing, imported)
    }

    static func shouldImportBookmark(
        existing: [LibraryBackupBookmarkEntry],
        candidate: LibraryBackupBookmarkEntry
    ) -> Bool {
        let timestampTolerance: TimeInterval = 0.5
        return !existing.contains { bookmark in
            bookmark.title == candidate.title
                && abs(bookmark.timestamp - candidate.timestamp) <= timestampTolerance
        }
    }
}

// MARK: - Matcher

enum LibraryBackupMatcher {
    struct LibraryBookCandidate: Equatable, Sendable {
        let fingerprint: AudiobookFingerprint
    }

    /// Returns manifest book entries that match a library fingerprint, in manifest order.
    static func match(
        manifest: LibraryBackupManifest,
        libraryFingerprints: [AudiobookFingerprint]
    ) -> [(entry: LibraryBackupBookEntry, libraryIndex: Int)] {
        var usedLibraryIndices = Set<Int>()
        var matches: [(LibraryBackupBookEntry, Int)] = []

        for entry in manifest.books {
            let target = entry.fingerprint.toAudiobookFingerprint()
            guard let libraryIndex = libraryFingerprints.enumerated().first(where: { index, fingerprint in
                !usedLibraryIndices.contains(index) && target.matches(fingerprint)
            })?.offset else {
                continue
            }
            usedLibraryIndices.insert(libraryIndex)
            matches.append((entry, libraryIndex))
        }

        return matches
    }

    static func unmatchedEntryCount(
        manifest: LibraryBackupManifest,
        libraryFingerprints: [AudiobookFingerprint]
    ) -> Int {
        let matched = match(manifest: manifest, libraryFingerprints: libraryFingerprints)
        return manifest.books.count - matched.count
    }
}

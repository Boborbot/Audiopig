//
//  LibraryBackupService.swift
//  Audiopig
//

import Foundation
import SwiftData

@MainActor
final class LibraryBackupService: LibraryBackupServiceProtocol {
    static let folderName = "Exported Library Backups"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func exportToDocuments(in context: ModelContext) throws -> URL {
        let manifest = try buildManifest(in: context)
        let data = try LibraryBackupManifestCodec.encode(manifest)
        let url = try exportFileURL()
        try data.write(to: url, options: .atomic)
        return url
    }

    func applyManifest(at fileURL: URL, in context: ModelContext) throws -> LibraryBackupApplyResult {
        let manifest = try LibraryBackupManifestCodec.decode(from: fileURL)
        return try apply(manifest, in: context)
    }

    // MARK: - Build

    func buildManifest(in context: ModelContext) throws -> LibraryBackupManifest {
        let audiobooks = try context.fetch(FetchDescriptor<Audiobook>())
        let folders = try context.fetch(FetchDescriptor<Folder>())

        let bookEntries: [LibraryBackupBookEntry] = try audiobooks.compactMap { audiobook in
            guard let fingerprint = libraryBackupFingerprint(for: audiobook) else { return nil }

            let bookmarks = audiobook.bookmarks
                .sorted { $0.timestamp < $1.timestamp }
                .map { bookmark in
                    LibraryBackupBookmarkEntry(
                        title: bookmark.title,
                        note: bookmark.note,
                        timestamp: bookmark.timestamp
                    )
                }

            return LibraryBackupBookEntry(
                fingerprint: fingerprint,
                title: audiobook.title,
                author: audiobook.author,
                currentPlaybackTime: audiobook.currentPlaybackTime,
                lastPlaybackSpeed: audiobook.lastPlaybackSpeed,
                lastPlayedAt: audiobook.lastPlayedAt,
                isManuallyFinished: audiobook.isManuallyFinished,
                bookmarks: bookmarks
            )
        }

        let folderEntries: [LibraryBackupFolderEntry] = folders.map { folder in
            let fingerprints = folder.audiobooks.compactMap { libraryBackupFingerprint(for: $0) }
            return LibraryBackupFolderEntry(title: folder.title, bookFingerprints: fingerprints)
        }

        return LibraryBackupManifest(books: bookEntries, folders: folderEntries)
    }

    // MARK: - Apply

    private func apply(_ manifest: LibraryBackupManifest, in context: ModelContext) throws -> LibraryBackupApplyResult {
        var result = LibraryBackupApplyResult.empty
        let audiobooks = try context.fetch(FetchDescriptor<Audiobook>())

        let libraryFingerprints: [AudiobookFingerprint] = audiobooks.compactMap { audiobook in
            libraryBackupFingerprint(for: audiobook)?.toAudiobookFingerprint()
        }

        let matches = LibraryBackupMatcher.match(manifest: manifest, libraryFingerprints: libraryFingerprints)
        result.unmatchedEntries = manifest.books.count - matches.count

        var audiobookByFingerprint = [String: Audiobook]()
        for audiobook in audiobooks {
            if let fingerprint = libraryBackupFingerprint(for: audiobook) {
                audiobookByFingerprint[fingerprint.stableID] = audiobook
            }
        }

        for (entry, _) in matches {
            guard let audiobook = audiobookByFingerprint[entry.fingerprint.stableID] else { continue }

            audiobook.currentPlaybackTime = LibraryBackupMergePolicy.mergedPlaybackTime(
                existing: audiobook.currentPlaybackTime,
                imported: entry.currentPlaybackTime
            )

            if let speed = entry.lastPlaybackSpeed {
                audiobook.lastPlaybackSpeed = speed
            }

            if let lastPlayedAt = entry.lastPlayedAt {
                if let existing = audiobook.lastPlayedAt {
                    audiobook.lastPlayedAt = max(existing, lastPlayedAt)
                } else {
                    audiobook.lastPlayedAt = lastPlayedAt
                }
            }

            if entry.isManuallyFinished {
                audiobook.isManuallyFinished = true
            }

            let existingBookmarkEntries = audiobook.bookmarks.map {
                LibraryBackupBookmarkEntry(title: $0.title, note: $0.note, timestamp: $0.timestamp)
            }

            for bookmarkEntry in entry.bookmarks {
                guard LibraryBackupMergePolicy.shouldImportBookmark(
                    existing: existingBookmarkEntries,
                    candidate: bookmarkEntry
                ) else {
                    continue
                }

                let bookmark = Bookmark(
                    title: bookmarkEntry.title,
                    note: bookmarkEntry.note,
                    timestamp: bookmarkEntry.timestamp,
                    audiobook: audiobook
                )
                context.insert(bookmark)
            }

            result.restoredBooks += 1
        }

        let folders = try context.fetch(FetchDescriptor<Folder>())
        var folderByTitle = Dictionary(uniqueKeysWithValues: folders.map { ($0.title, $0) })

        for folderEntry in manifest.folders {
            let folder = folderByTitle[folderEntry.title] ?? {
                let created = Folder(title: folderEntry.title)
                context.insert(created)
                folderByTitle[folderEntry.title] = created
                return created
            }()

            for fingerprint in folderEntry.bookFingerprints {
                guard let audiobook = audiobookByFingerprint[fingerprint.stableID] else { continue }
                audiobook.folder = folder
            }

            result.foldersApplied += 1
        }

        try context.save()
        return result
    }

    // MARK: - Paths

    static func exportFolderURL(using fileManager: FileManager = .default) throws -> URL {
        guard let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw LibraryBackupServiceError.documentsUnavailable
        }
        let folder = documents.appendingPathComponent(folderName, isDirectory: true)
        if !fileManager.fileExists(atPath: folder.path) {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        }
        return folder
    }

    private func exportFileURL() throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        let dateStamp = formatter.string(from: .now)
        let filename = "Audiopig_Library_Backup_\(dateStamp).json"
        return try Self.exportFolderURL(using: fileManager).appendingPathComponent(filename)
    }

    private func libraryBackupFingerprint(for audiobook: Audiobook) -> LibraryBackupFingerprint? {
        guard let fileSize = fileSize(at: audiobook.fileURL) else { return nil }
        return LibraryBackupFingerprint(
            fileName: audiobook.fileURL.lastPathComponent,
            fileSize: fileSize,
            duration: audiobook.duration
        )
    }

    private func fileSize(at url: URL) -> Int64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }
}

enum LibraryBackupServiceError: Error {
    case documentsUnavailable
}

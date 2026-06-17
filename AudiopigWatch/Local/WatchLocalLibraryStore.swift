//
//  WatchLocalLibraryStore.swift
//  AudiopigWatch
//

import CryptoKit
import Foundation

@MainActor
final class WatchLocalLibraryStore: WatchLocalLibraryStoring {
    let budgetBytes: Int64

    private let fileManager: FileManager
    private let rootURL: URL

    init(fileManager: FileManager = .default, budgetBytes: Int64 = WatchStorageBudget.defaultBudgetBytes) {
        self.fileManager = fileManager
        self.budgetBytes = budgetBytes
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.rootURL = appSupport.appendingPathComponent("TransferredBooks", isDirectory: true)
        try? fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
    }

    func allBooks() -> [WatchBookSummary] {
        allManifests().map { manifest in
            WatchBookSummary(
                id: manifest.bookID,
                title: manifest.title,
                author: manifest.author,
                duration: manifest.duration,
                currentPlaybackTime: manifest.resumePosition,
                lastPlayedAt: manifest.lastPlayedAt,
                thumbnailJPEG: manifest.thumbnailJPEG
            )
        }
        .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
    }

    func allManifests() -> [WatchTransferManifest] {
        guard let bookDirs = try? fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return bookDirs.compactMap { dir in
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
            return readManifest(at: manifestURL(forBookDirectory: dir))
        }
    }

    func manifest(for bookID: UUID) -> WatchTransferManifest? {
        readManifest(at: bookDirectory(for: bookID).appendingPathComponent("manifest.json"))
    }

    func localURL(for bookID: UUID) -> URL? {
        guard let manifest = manifest(for: bookID) else { return nil }
        let url = audioURL(for: bookID, extension: manifest.fileExtension)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func usedBytes() -> Int64 {
        allManifests().reduce(0) { $0 + $1.fileByteCount }
    }

    func localBooksPayload() -> WatchLocalBooksPayload {
        let manifests = allManifests()
        let books = manifests
            .map { manifest in
                WatchBookSummary(
                    id: manifest.bookID,
                    title: manifest.title,
                    author: manifest.author,
                    duration: manifest.duration,
                    currentPlaybackTime: manifest.resumePosition,
                    lastPlayedAt: manifest.lastPlayedAt,
                    thumbnailJPEG: manifest.thumbnailJPEG
                )
            }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
        let used = manifests.reduce(Int64(0)) { $0 + $1.fileByteCount }
        return WatchLocalBooksPayload(books: books, usedBytes: used, budgetBytes: budgetBytes)
    }

    func ingest(transferredFile: URL, manifest: WatchTransferManifest) throws -> WatchTransferManifest {
        let existingManifests = allManifests()
        let entries = existingManifests
            .filter { $0.bookID != manifest.bookID }
            .map(storageEntry(from:))

        if !WatchStorageBudget.canFit(entries: entries, incomingBytes: manifest.fileByteCount, budget: budgetBytes) {
            let evictions = WatchStorageBudget.booksToEvict(
                entries: existingManifests.map(storageEntry(from:)),
                incomingBytes: manifest.fileByteCount,
                budget: budgetBytes
            )
            for bookID in evictions {
                try? remove(bookID: bookID)
            }
            let refreshed = allManifests()
                .filter { $0.bookID != manifest.bookID }
                .map(storageEntry(from:))
            guard WatchStorageBudget.canFit(entries: refreshed, incomingBytes: manifest.fileByteCount, budget: budgetBytes) else {
                throw WatchLocalLibraryError.storageFull
            }
        }

        let bookDir = bookDirectory(for: manifest.bookID)
        if fileManager.fileExists(atPath: bookDir.path) {
            try fileManager.removeItem(at: bookDir)
        }
        try fileManager.createDirectory(at: bookDir, withIntermediateDirectories: true)

        let destination = audioURL(for: manifest.bookID, extension: manifest.fileExtension)
        try fileManager.moveItem(at: transferredFile, to: destination)

        let checksum = try Self.sha256(of: destination)
        guard checksum == manifest.sha256 else {
            try? fileManager.removeItem(at: bookDir)
            throw WatchLocalLibraryError.checksumMismatch
        }

        let storedManifest = WatchTransferManifest(
            bookID: manifest.bookID,
            title: manifest.title,
            author: manifest.author,
            duration: manifest.duration,
            chapters: manifest.chapters,
            fileByteCount: manifest.fileByteCount,
            sha256: manifest.sha256,
            fileExtension: manifest.fileExtension,
            transferredAt: manifest.transferredAt,
            thumbnailJPEG: manifest.thumbnailJPEG,
            resumePosition: manifest.resumePosition,
            lastPlayedAt: manifest.lastPlayedAt
        )
        try writeManifest(storedManifest)
        return storedManifest
    }

    func remove(bookID: UUID) throws {
        let dir = bookDirectory(for: bookID)
        guard fileManager.fileExists(atPath: dir.path) else {
            throw WatchLocalLibraryError.bookNotFound
        }
        try fileManager.removeItem(at: dir)
    }

    func updateResumePosition(bookID: UUID, time: TimeInterval) throws {
        guard var existing = manifest(for: bookID) else {
            throw WatchLocalLibraryError.bookNotFound
        }
        existing = WatchTransferManifest(
            bookID: existing.bookID,
            title: existing.title,
            author: existing.author,
            duration: existing.duration,
            chapters: existing.chapters,
            fileByteCount: existing.fileByteCount,
            sha256: existing.sha256,
            fileExtension: existing.fileExtension,
            transferredAt: existing.transferredAt,
            thumbnailJPEG: existing.thumbnailJPEG,
            resumePosition: time,
            lastPlayedAt: existing.lastPlayedAt
        )
        try writeManifest(existing)
    }

    func updateLastPlayed(bookID: UUID) throws {
        guard var existing = manifest(for: bookID) else {
            throw WatchLocalLibraryError.bookNotFound
        }
        existing = WatchTransferManifest(
            bookID: existing.bookID,
            title: existing.title,
            author: existing.author,
            duration: existing.duration,
            chapters: existing.chapters,
            fileByteCount: existing.fileByteCount,
            sha256: existing.sha256,
            fileExtension: existing.fileExtension,
            transferredAt: existing.transferredAt,
            thumbnailJPEG: existing.thumbnailJPEG,
            resumePosition: existing.resumePosition,
            lastPlayedAt: .now
        )
        try writeManifest(existing)
    }

    // MARK: - Private

    private func bookDirectory(for bookID: UUID) -> URL {
        rootURL.appendingPathComponent(bookID.uuidString, isDirectory: true)
    }

    private func audioURL(for bookID: UUID, extension ext: String) -> URL {
        bookDirectory(for: bookID).appendingPathComponent("audio.\(ext)")
    }

    private func manifestURL(forBookDirectory dir: URL) -> URL {
        dir.appendingPathComponent("manifest.json")
    }

    private func readManifest(at url: URL) -> WatchTransferManifest? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? WatchMessageCodec.decode(WatchTransferManifest.self, from: data)
    }

    private func writeManifest(_ manifest: WatchTransferManifest) throws {
        let data = try WatchMessageCodec.encode(manifest)
        try data.write(to: bookDirectory(for: manifest.bookID).appendingPathComponent("manifest.json"), options: .atomic)
    }

    private func storageEntry(from manifest: WatchTransferManifest) -> WatchStorageEntry {
        WatchStorageEntry(
            bookID: manifest.bookID,
            byteCount: manifest.fileByteCount,
            lastPlayedAt: manifest.lastPlayedAt,
            transferredAt: manifest.transferredAt
        )
    }

    nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1_048_576)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}

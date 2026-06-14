//
//  LibraryManager.swift
//  Audiopig
//

import Foundation
import SwiftData

@MainActor
final class LibraryManager: LibraryManagerProtocol {
    let libraryDirectoryURL: URL

    private let metadataExtractor: AudiobookMetadataExtractor
    private let fileManager: FileManager

    init(
        libraryDirectoryURL: URL? = nil,
        metadataExtractor: AudiobookMetadataExtractor = AudiobookMetadataExtractor(),
        fileManager: FileManager = .default
    ) throws {
        self.metadataExtractor = metadataExtractor
        self.fileManager = fileManager

        if let libraryDirectoryURL {
            self.libraryDirectoryURL = libraryDirectoryURL
        } else {
            self.libraryDirectoryURL = try Self.defaultLibraryDirectory(using: fileManager)
        }

        try ensureLibraryDirectoryExists()
    }

    func extractMetadata(from fileURL: URL) async throws -> AudiobookImportMetadata {
        do {
            return try await metadataExtractor.extract(from: fileURL)
        } catch let error as LibraryManagerError {
            throw error
        } catch {
            throw LibraryManagerError.metadataExtractionFailed
        }
    }

    func importAudiobook(from sourceURL: URL) async throws -> AudiobookImportMetadata {
        guard fileExists(at: sourceURL) else {
            throw LibraryManagerError.fileNotFound
        }

        guard SupportedAudioExtension.isSupported(sourceURL) else {
            throw LibraryManagerError.unsupportedFileFormat
        }

        let resolvedSourceURL = sourceURL.standardizedFileURL
        let resolvedLibraryURL = libraryDirectoryURL.standardizedFileURL

        if resolvedSourceURL.deletingLastPathComponent() == resolvedLibraryURL {
            return try await extractMetadata(from: resolvedSourceURL)
        }

        let destinationURL = uniqueDestinationURL(for: resolvedSourceURL.lastPathComponent)

        do {
            try fileManager.copyItem(at: resolvedSourceURL, to: destinationURL)
        } catch {
            throw LibraryManagerError.fileSystemOperationFailed
        }

        return try await extractMetadata(from: destinationURL)
    }

    func scanDirectory(at directoryURL: URL) async throws -> [AudiobookImportMetadata] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw LibraryManagerError.fileNotFound
        }

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw LibraryManagerError.fileSystemOperationFailed
        }

        var metadataResults: [AudiobookImportMetadata] = []

        for case let fileURL as URL in enumerator {
            guard SupportedAudioExtension.isSupported(fileURL) else {
                continue
            }

            let metadata = try await extractMetadata(from: fileURL)
            metadataResults.append(metadata)
        }

        return metadataResults.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func persist(metadata: AudiobookImportMetadata, in context: ModelContext) throws -> Audiobook {
        let audiobook = Audiobook(
            title: metadata.title,
            author: metadata.author,
            duration: metadata.duration,
            currentPlaybackTime: 0,
            coverArtwork: metadata.coverArtwork,
            fileURL: metadata.fileURL
        )

        let chapters = metadata.chapters
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { chapterMetadata in
                Chapter(
                    title: chapterMetadata.title,
                    duration: chapterMetadata.duration,
                    startTime: chapterMetadata.startTime,
                    orderIndex: chapterMetadata.orderIndex,
                    fileURL: chapterMetadata.fileURL,
                    audiobook: audiobook
                )
            }

        audiobook.chapters = chapters
        context.insert(audiobook)

        do {
            try context.save()
        } catch {
            throw LibraryManagerError.importFailed
        }

        return audiobook
    }

    func importAndPersist(from sourceURL: URL, in context: ModelContext) async throws -> Audiobook {
        let metadata = try await importAudiobook(from: sourceURL)

        do {
            return try persist(metadata: metadata, in: context)
        } catch let error as LibraryManagerError {
            if metadata.fileURL.deletingLastPathComponent() == libraryDirectoryURL.standardizedFileURL {
                try? deleteAudiobookFile(at: metadata.fileURL)
            }
            throw error
        } catch {
            if metadata.fileURL.deletingLastPathComponent() == libraryDirectoryURL.standardizedFileURL {
                try? deleteAudiobookFile(at: metadata.fileURL)
            }
            throw LibraryManagerError.importFailed
        }
    }

    func deleteAudiobookFile(at fileURL: URL) throws {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw LibraryManagerError.fileNotFound
        }

        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw LibraryManagerError.fileSystemOperationFailed
        }
    }

    func fileExists(at fileURL: URL) -> Bool {
        fileManager.fileExists(atPath: fileURL.path)
    }

    func merge(audiobooks: [Audiobook], intoTitle title: String, in context: ModelContext) throws -> Audiobook {
        guard audiobooks.count >= 2 else {
            throw LibraryManagerError.insufficientAudiobooksForMerge
        }

        let uniqueIDs = Set(audiobooks.map(\.id))
        guard uniqueIDs.count == audiobooks.count else {
            throw LibraryManagerError.mergeFailed
        }

        let masterAudiobook = audiobooks[0]
        let masterOriginalTitle = masterAudiobook.title
        masterAudiobook.title = title

        // Snapshot absorbed audiobooks' book-level file URLs before any mutation.
        // After chapters are re-parented these records are deleted; any URL that isn't
        // covered by a surviving chapter in the master is an orphan and should be removed.
        let absorbedFileURLs = audiobooks.dropFirst().map(\.fileURL)

        var timelineOffset = masterAudiobook.duration
        var nextOrderIndex = (masterAudiobook.chapters.map(\.orderIndex).max() ?? -1) + 1

        // For single-file master books, name the chapter after the original book title
        // so chapter navigation in the merged result is meaningful.
        let masterChapters = masterAudiobook.chapters.sorted { $0.orderIndex < $1.orderIndex }
        if masterChapters.count == 1 {
            masterChapters[0].title = masterOriginalTitle
        }

        for absorbedAudiobook in audiobooks.dropFirst() {
            let chaptersToAbsorb = absorbedAudiobook.chapters.sorted { $0.orderIndex < $1.orderIndex }

            for chapter in chaptersToAbsorb {
                // For single-file books (one chapter), name the chapter after the book
                // so the merged result's chapter list is navigable by original book title.
                if chaptersToAbsorb.count == 1 {
                    chapter.title = absorbedAudiobook.title
                }
                chapter.startTime = timelineOffset + chapter.startTime
                chapter.orderIndex = nextOrderIndex
                chapter.audiobook = masterAudiobook
                nextOrderIndex += 1
            }

            timelineOffset += absorbedAudiobook.duration
            context.delete(absorbedAudiobook)
        }

        masterAudiobook.duration = timelineOffset

        let sortedMasterChapters = masterAudiobook.chapters.sorted { $0.orderIndex < $1.orderIndex }
        if let primaryChapterURL = sortedMasterChapters.first?.fileURL {
            masterAudiobook.fileURL = primaryChapterURL
        }

        do {
            try context.save()
        } catch {
            throw LibraryManagerError.mergeFailed
        }

        // Delete any absorbed book-level files that are no longer referenced by a chapter
        // in the merged result. In the typical single-file-per-book case every absorbed
        // fileURL is reused as a chapter URL so nothing is deleted; this guard handles
        // future edge cases where the book-level URL diverges from its chapter URLs.
        let masterChapterURLs = Set(masterAudiobook.chapters.map(\.fileURL))
        for fileURL in absorbedFileURLs where !masterChapterURLs.contains(fileURL) {
            try? deleteAudiobookFile(at: fileURL)
        }

        return masterAudiobook
    }

    private func ensureLibraryDirectoryExists() throws {
        if fileManager.fileExists(atPath: libraryDirectoryURL.path) {
            return
        }

        do {
            try fileManager.createDirectory(
                at: libraryDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw LibraryManagerError.fileSystemOperationFailed
        }
    }

    private func uniqueDestinationURL(for fileName: String) -> URL {
        let fileExtension = (fileName as NSString).pathExtension
        let baseName = (fileName as NSString).deletingPathExtension
        var candidate = libraryDirectoryURL.appendingPathComponent(fileName)
        var duplicateIndex = 1

        while fileManager.fileExists(atPath: candidate.path) {
            let suffixedName: String
            if fileExtension.isEmpty {
                suffixedName = "\(baseName)-\(duplicateIndex)"
            } else {
                suffixedName = "\(baseName)-\(duplicateIndex).\(fileExtension)"
            }

            candidate = libraryDirectoryURL.appendingPathComponent(suffixedName)
            duplicateIndex += 1
        }

        return candidate
    }

    private static func defaultLibraryDirectory(using fileManager: FileManager) throws -> URL {
        let applicationSupportDirectory = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupportDirectory
            .appendingPathComponent("Audiopig", isDirectory: true)
            .appendingPathComponent("Library", isDirectory: true)
    }
}

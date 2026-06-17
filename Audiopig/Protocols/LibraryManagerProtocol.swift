//
//  LibraryManagerProtocol.swift
//  Audiopig
//

import Foundation
import SwiftData

/// Parses M4B/MP3 files, extracts metadata, and performs library file-system operations.
@MainActor
protocol LibraryManagerProtocol: AnyObject {
    /// Returns the on-disk directory where imported audiobooks are stored.
    var libraryDirectoryURL: URL { get }

    /// Extracts metadata from a single audio file without importing it into the library.
    func extractMetadata(from fileURL: URL) async throws -> AudiobookImportMetadata

    /// Copies a file into the managed library directory and returns its metadata.
    func importAudiobook(from sourceURL: URL) async throws -> AudiobookImportMetadata

    /// Scans a directory for supported audio files and returns metadata for each match.
    func scanDirectory(at directoryURL: URL) async throws -> [AudiobookImportMetadata]

    /// Persists extracted metadata as SwiftData models.
    func persist(metadata: AudiobookImportMetadata, in context: ModelContext) throws -> Audiobook

    /// Imports a file into the library directory and persists it to SwiftData.
    func importAndPersist(from sourceURL: URL, in context: ModelContext) async throws -> Audiobook

    /// Merges multiple audiobooks into a single virtual audiobook with stacked chapter timelines.
    func merge(audiobooks: [Audiobook], intoTitle title: String, in context: ModelContext) throws -> Audiobook

    /// Removes an audiobook file from the library directory.
    func deleteAudiobookFile(at fileURL: URL) throws

    /// Verifies that a file URL still resolves to an accessible resource on disk.
    func fileExists(at fileURL: URL) -> Bool

    /// Re-resolves a stored file URL against the managed library directory when the
    /// absolute path is stale (e.g. after a simulator reinstall).
    func repairStoredFileURL(_ storedURL: URL) -> URL

    /// Updates audiobook and chapter file URLs when their stored paths no longer exist.
    func repairAudiobookFileReferences(in context: ModelContext) throws

    /// Returns true when every chapter file for the audiobook is reachable on disk.
    func isAudiobookPlayable(_ audiobook: Audiobook) -> Bool
}

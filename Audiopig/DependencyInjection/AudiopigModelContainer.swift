//
//  AudiopigModelContainer.swift
//  Audiopig
//

import SwiftData
import OSLog

private let log = Logger(subsystem: "com.audiopig", category: "ModelContainer")

// MARK: - Container factory

/// Creates the SwiftData ModelContainer for the full app schema.
///
/// SwiftData performs inferred (lightweight) migration automatically for additive
/// schema changes — new attributes with default values, new optional relationships,
/// new model types — so an explicit VersionedSchema / SchemaMigrationPlan is only
/// needed for destructive or renaming changes. Keep this simple until such a change
/// is required.
enum AudiopigModelContainer {

    private static let models: [any PersistentModel.Type] = [
        Audiobook.self, Chapter.self, Bookmark.self, SubtitleCue.self,
        SubtitleTranscriptionSegment.self,
        WholeBookTranscriptionQueueEntry.self,
        FinishedRecord.self, Folder.self
    ]

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            guard !isStoredInMemoryOnly else { throw error }
            log.error("ModelContainer open failed: \(error.localizedDescription, privacy: .public)")
            try removeStoreFiles(at: try defaultStoreURL())
            return try ModelContainer(for: schema, configurations: configuration)
        }
    }

    private static func defaultStoreURL() throws -> URL {
        let applicationSupportDirectory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return applicationSupportDirectory.appendingPathComponent("default.store")
    }

    /// Last-resort recovery when the store cannot be opened.
    /// Audio files in the managed library directory are left on disk for re-import.
    private static func removeStoreFiles(at storeURL: URL) throws {
        let fileManager = FileManager.default
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
        let externalStorage = URL(fileURLWithPath: storeURL.path + ".externalStorage")
        if fileManager.fileExists(atPath: externalStorage.path) {
            try fileManager.removeItem(at: externalStorage)
        }
    }
}

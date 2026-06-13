//
//  AudiopigModelContainer.swift
//  Audiopig
//

import SwiftData
import OSLog

private let log = Logger(subsystem: "com.audiopig", category: "ModelContainer")

enum AudiopigModelContainer {
    static let schema = Schema([
        Audiobook.self,
        Chapter.self,
        Bookmark.self,
    ])

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // SwiftDataError 1 = incompatible schema on disk (e.g. model changed during
            // development). Destroy the old store and create a fresh one rather than
            // crashing. In a shipped app we would provide a proper migration plan instead.
            log.warning("ModelContainer failed (\(error.localizedDescription)); destroying incompatible store and starting fresh.")
            try destroyStore(for: configuration)
            return try ModelContainer(for: schema, configurations: configuration)
        }
    }

    // MARK: - Private

    private static func destroyStore(for configuration: ModelConfiguration) throws {
        let storeURL = configuration.url
        let fm = FileManager.default
        // SwiftData writes a .store file plus auxiliary -wal and -shm files.
        let auxiliaryExtensions = ["", "-wal", "-shm"]
        for ext in auxiliaryExtensions {
            let url = URL(fileURLWithPath: storeURL.path + ext)
            if fm.fileExists(atPath: url.path) {
                try fm.removeItem(at: url)
                log.info("Deleted store file: \(url.lastPathComponent)")
            }
        }
    }
}

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
        Audiobook.self, Chapter.self, Bookmark.self, FinishedRecord.self, Folder.self
    ]

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

//
//  AudiopigModelContainer.swift
//  Audiopig
//

import SwiftData
import OSLog

private let log = Logger(subsystem: "com.audiopig", category: "ModelContainer")

// MARK: - Schema versioning

/// The v1.0 schema. Add a new VersionedSchema enum for every shipping schema change,
/// then add a MigrationStage to AudiopigMigrationPlan.
enum AudiopigSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Audiobook.self, Chapter.self, Bookmark.self, FinishedRecord.self]
    }
}

/// Migration plan wired into ModelContainer. Currently a single-version plan; extend
/// with new VersionedSchema types and MigrationStage entries as the schema evolves.
enum AudiopigMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [AudiopigSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}

// MARK: - Container factory

enum AudiopigModelContainer {

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(
            for: Schema(AudiopigSchemaV1.models),
            migrationPlan: AudiopigMigrationPlan.self,
            configurations: configuration
        )
    }
}

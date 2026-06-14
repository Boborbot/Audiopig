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
        [Audiobook.self, Chapter.self, Bookmark.self, FinishedRecord.self, Folder.self]
    }
}

/// v2.0 — adds Bookmark.note (String, default "") for per-bookmark annotations.
enum AudiopigSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Audiobook.self, Chapter.self, Bookmark.self, FinishedRecord.self, Folder.self]
    }
}

/// Migration plan wired into ModelContainer. Extend with new VersionedSchema types
/// and MigrationStage entries as the schema evolves.
enum AudiopigMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [AudiopigSchemaV1.self, AudiopigSchemaV2.self]
    }
    static var stages: [MigrationStage] { [v1ToV2] }

    /// Lightweight migration: adds Bookmark.note (additive attribute with default "").
    static let v1ToV2 = MigrationStage.lightweight(
        fromVersion: AudiopigSchemaV1.self,
        toVersion: AudiopigSchemaV2.self
    )
}

// MARK: - Container factory

enum AudiopigModelContainer {

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(
            for: Schema(AudiopigSchemaV2.models),
            migrationPlan: AudiopigMigrationPlan.self,
            configurations: configuration
        )
    }
}

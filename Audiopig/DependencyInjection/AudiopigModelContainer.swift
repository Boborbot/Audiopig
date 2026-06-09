//
//  AudiopigModelContainer.swift
//  Audiopig
//

import SwiftData

enum AudiopigModelContainer {
    static let schema = Schema([
        Audiobook.self,
        Chapter.self,
        Bookmark.self,
    ])

    static func make(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: configuration)
    }
}

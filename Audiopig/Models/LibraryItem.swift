//
//  LibraryItem.swift
//  Audiopig
//

import Foundation

/// A discriminated union representing a top-level item in the library list —
/// either a standalone audiobook or a folder containing multiple audiobooks.
enum LibraryItem: Identifiable {
    case audiobook(Audiobook)
    case folder(Folder)

    var id: UUID {
        switch self {
        case .audiobook(let b): return b.id
        case .folder(let f): return f.id
        }
    }

    var sortTitle: String {
        switch self {
        case .audiobook(let b): return b.title
        case .folder(let f): return f.title
        }
    }
}

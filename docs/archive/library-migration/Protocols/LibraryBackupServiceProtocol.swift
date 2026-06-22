//
//  LibraryBackupServiceProtocol.swift
//  Audiopig
//

import Foundation
import SwiftData

@MainActor
protocol LibraryBackupServiceProtocol: AnyObject {
    /// Builds a manifest from the current library and writes it to Documents for Files app access.
    func exportToDocuments(in context: ModelContext) throws -> URL

    /// Applies playback state, bookmarks, and folders from a user-selected backup file.
    func applyManifest(at fileURL: URL, in context: ModelContext) throws -> LibraryBackupApplyResult
}

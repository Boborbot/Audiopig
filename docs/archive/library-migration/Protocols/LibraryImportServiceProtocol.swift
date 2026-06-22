//
//  LibraryImportServiceProtocol.swift
//  Audiopig
//

import Foundation
import SwiftData

@MainActor
protocol LibraryImportServiceProtocol: AnyObject {
    /// Imports all supported audiobooks discovered under a user-selected folder.
    func importFolder(at folderURL: URL, in context: ModelContext) async -> LibraryImportResult
}

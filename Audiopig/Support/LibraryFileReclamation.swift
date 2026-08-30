//
//  LibraryFileReclamation.swift
//  Audiopig
//

import Foundation

/// Pure helpers for deciding which managed library files are safe to remove.
enum LibraryFileReclamation: Sendable {

    /// Returns managed-library files that are not referenced by any remaining book or chapter.
    static func filesToRemove(
        candidates: [URL],
        referencedPaths: Set<String>,
        libraryDirectoryURL: URL
    ) -> [URL] {
        let libraryPath = libraryDirectoryURL.standardizedFileURL.path
        var seen = Set<String>()
        var result: [URL] = []

        for url in candidates {
            let standardized = url.standardizedFileURL
            let path = standardized.path
            guard seen.insert(path).inserted else { continue }
            guard isInsideLibraryDirectory(path, libraryPath: libraryPath) else { continue }
            guard !referencedPaths.contains(path) else { continue }
            result.append(standardized)
        }

        return result
    }

    static func isInsideLibraryDirectory(_ path: String, libraryPath: String) -> Bool {
        path == libraryPath || path.hasPrefix(libraryPath.hasSuffix("/") ? libraryPath : libraryPath + "/")
    }
}

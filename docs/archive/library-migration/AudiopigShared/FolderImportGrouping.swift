//
//  FolderImportGrouping.swift
//  AudiopigShared
//

import Foundation

/// A set of audio files that belong to one audiobook (single file or multi-file MP3 volume).
struct FolderImportGroup: Equatable, Sendable {
    /// Path from the import root to the containing folder, using forward slashes. Empty for files at the root.
    let relativeDirectory: String
    /// Member file names sorted for stable chapter order.
    let fileNames: [String]

    var isMultiFileVolume: Bool { fileNames.count > 1 }
}

enum FolderImportGrouping {
    static let supportedExtensions: Set<String> = ["m4b", "mp3"]

    /// Groups relative file paths (forward slashes, no leading slash) into import volumes.
    static func group(relativeFilePaths: [String]) -> [FolderImportGroup] {
        var buckets: [String: [String]] = [:]

        for path in relativeFilePaths {
            let normalized = normalize(path)
            guard let fileName = fileName(from: normalized),
                  isSupported(fileName: fileName) else {
                continue
            }

            let directory = directoryPath(from: normalized)
            buckets[directory, default: []].append(fileName)
        }

        return buckets
            .map { directory, names in
                FolderImportGroup(
                    relativeDirectory: directory,
                    fileNames: names.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                )
            }
            .sorted { lhs, rhs in
                let leftKey = lhs.relativeDirectory.isEmpty ? lhs.fileNames.first ?? "" : lhs.relativeDirectory
                let rightKey = rhs.relativeDirectory.isEmpty ? rhs.fileNames.first ?? "" : rhs.relativeDirectory
                return leftKey.localizedStandardCompare(rightKey) == .orderedAscending
            }
    }

    /// Suggested display title for a grouped volume.
    static func suggestedTitle(for group: FolderImportGroup, primaryFileTitle: String) -> String {
        if !group.relativeDirectory.isEmpty {
            let components = group.relativeDirectory.split(separator: "/")
            if let last = components.last, !last.isEmpty {
                return String(last)
            }
        }
        return primaryFileTitle
    }

    private static func normalize(_ path: String) -> String {
        path.replacingOccurrences(of: "\\", with: "/")
    }

    private static func directoryPath(from normalizedPath: String) -> String {
        let url = URL(fileURLWithPath: normalizedPath)
        let directory = url.deletingLastPathComponent().path
        if directory == "." { return "" }
        return directory
    }

    private static func fileName(from normalizedPath: String) -> String? {
        let name = URL(fileURLWithPath: normalizedPath).lastPathComponent
        return name.isEmpty ? nil : name
    }

    private static func isSupported(fileName: String) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return supportedExtensions.contains(ext)
    }
}

//
//  LibraryImportService.swift
//  Audiopig
//

import Foundation
import SwiftData

@MainActor
final class LibraryImportService: LibraryImportServiceProtocol {
    private let libraryManager: any LibraryManagerProtocol
    private let fileManager: FileManager

    init(
        libraryManager: any LibraryManagerProtocol,
        fileManager: FileManager = .default
    ) {
        self.libraryManager = libraryManager
        self.fileManager = fileManager
    }

    func importFolder(at folderURL: URL, in context: ModelContext) async -> LibraryImportResult {
        var result = LibraryImportResult.empty

        let groups: [ResolvedImportGroup]
        do {
            groups = try discoverGroups(at: folderURL)
        } catch {
            result.failed.append(LibraryImportFailure(name: folderURL.lastPathComponent, reason: "Could not read folder."))
            return result
        }

        guard !groups.isEmpty else {
            result.failed.append(LibraryImportFailure(name: folderURL.lastPathComponent, reason: "No supported audio files found."))
            return result
        }

        let existingFingerprints = existingLibraryFingerprints(in: context)

        for group in groups {
            let displayName = group.displayName

            do {
                if try await isDuplicate(group: group, existingFingerprints: existingFingerprints) {
                    result.skippedDuplicateCount += 1
                    continue
                }

                if group.fileURLs.count == 1, let fileURL = group.fileURLs.first {
                    _ = try await libraryManager.importAndPersist(from: fileURL, in: context)
                } else {
                    let metadata = try await libraryManager.importVolume(
                        from: group.fileURLs,
                        suggestedTitle: group.suggestedTitle
                    )
                    _ = try libraryManager.persist(metadata: metadata, in: context)
                }

                result.importedCount += 1
            } catch {
                result.failed.append(LibraryImportFailure(name: displayName, reason: "Import failed."))
            }
        }

        return result
    }

    // MARK: - Discovery

    private struct ResolvedImportGroup {
        let relativeDirectory: String
        let fileURLs: [URL]
        let suggestedTitle: String?
        let displayName: String
    }

    private func discoverGroups(at folderURL: URL) throws -> [ResolvedImportGroup] {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LibraryManagerError.fileNotFound
        }

        let rootPath = folderURL.standardizedFileURL.path
        var relativePaths: [String] = []

        guard let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw LibraryManagerError.fileSystemOperationFailed
        }

        while let fileURL = enumerator.nextObject() as? URL {
            let standardized = fileURL.standardizedFileURL
            let relativePath = standardized.path
                .replacingOccurrences(of: rootPath + "/", with: "")
            relativePaths.append(relativePath)
        }

        let grouped = FolderImportGrouping.group(relativeFilePaths: relativePaths)

        return grouped.map { group in
            let urls = group.fileNames.map { fileName in
                group.relativeDirectory.isEmpty
                    ? folderURL.appendingPathComponent(fileName)
                    : folderURL.appendingPathComponent(group.relativeDirectory).appendingPathComponent(fileName)
            }

            let primaryFileTitle = (group.fileNames.first as NSString?)?.deletingPathExtension ?? "Audiobook"
            let displayName: String
            if !group.relativeDirectory.isEmpty {
                displayName = (group.relativeDirectory as NSString).lastPathComponent
            } else {
                displayName = primaryFileTitle
            }

            return ResolvedImportGroup(
                relativeDirectory: group.relativeDirectory,
                fileURLs: urls,
                suggestedTitle: FolderImportGrouping.suggestedTitle(
                    for: group,
                    primaryFileTitle: primaryFileTitle
                ),
                displayName: displayName
            )
        }
    }

    // MARK: - Duplicate Detection

    private func existingLibraryFingerprints(in context: ModelContext) -> Set<AudiobookFingerprint> {
        let descriptor = FetchDescriptor<Audiobook>()
        guard let audiobooks = try? context.fetch(descriptor) else { return [] }

        var fingerprints = Set<AudiobookFingerprint>()
        for audiobook in audiobooks {
            if let fingerprint = fingerprint(for: audiobook.fileURL, duration: audiobook.duration) {
                fingerprints.insert(fingerprint)
            }
        }
        return fingerprints
    }

    private func isDuplicate(
        group: ResolvedImportGroup,
        existingFingerprints: Set<AudiobookFingerprint>
    ) async throws -> Bool {
        if group.fileURLs.count == 1, let fileURL = group.fileURLs.first {
            let metadata = try await libraryManager.extractMetadata(from: fileURL)
            guard let candidate = fingerprint(for: fileURL, duration: metadata.duration) else {
                return false
            }
            return existingFingerprints.contains(where: { candidate.matches($0) })
        }

        var totalDuration: TimeInterval = 0
        var primaryFingerprint: AudiobookFingerprint?

        for (index, fileURL) in group.fileURLs.enumerated() {
            let metadata = try await libraryManager.extractMetadata(from: fileURL)
            totalDuration += metadata.duration
            if index == 0 {
                primaryFingerprint = fingerprint(for: fileURL, duration: metadata.duration)
            }
        }

        guard let primaryFingerprint else { return false }

        let volumeFingerprint = AudiobookFingerprint(
            normalizedFileName: primaryFingerprint.normalizedFileName,
            fileSize: primaryFingerprint.fileSize,
            duration: totalDuration
        )

        return existingFingerprints.contains { existing in
            existing.normalizedFileName == volumeFingerprint.normalizedFileName
                && abs(existing.duration - volumeFingerprint.duration) <= AudiobookFingerprint.durationTolerance
        }
    }

    private func fingerprint(for fileURL: URL, duration: TimeInterval) -> AudiobookFingerprint? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }

        return AudiobookFingerprint(
            normalizedFileName: fileURL.lastPathComponent,
            fileSize: fileSize,
            duration: duration
        )
    }
}

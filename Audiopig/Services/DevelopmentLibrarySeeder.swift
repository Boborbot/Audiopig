//
//  DevelopmentLibrarySeeder.swift
//  Audiopig
//
//  Debug-only: imports bundled test audiobooks into the library on launch.
//  Skips files that already have a playable library entry (matched by filename).
//

#if DEBUG
import Foundation
import SwiftData

enum DevelopmentLibrarySeeder {
    static let bundleSubdirectory = "Assets for Testing"

    static func seedIfNeeded(
        libraryManager: any LibraryManagerProtocol,
        modelContext: ModelContext
    ) async {
        try? libraryManager.repairAudiobookFileReferences(in: modelContext)

        guard let assetsURL = bundledAssetsURL() else { return }

        let fileURLs = discoverSupportedAudioFiles(in: assetsURL)

        for fileURL in fileURLs {
            let fileName = fileURL.lastPathComponent

            if let existing = audiobook(matchingFileName: fileName, in: modelContext) {
                if libraryManager.isAudiobookPlayable(existing) {
                    continue
                }
                removeAudiobook(existing, libraryManager: libraryManager, in: modelContext)
            }

            do {
                _ = try await libraryManager.importAndPersist(from: fileURL, in: modelContext)
            } catch {
                // Best-effort seeding for local development; failures are non-fatal.
            }
        }
    }

    private static func bundledAssetsURL() -> URL? {
        guard let resourceURL = Bundle.main.resourceURL else { return nil }
        let assetsURL = resourceURL.appendingPathComponent(bundleSubdirectory, isDirectory: true)
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: assetsURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            return nil
        }
        return assetsURL
    }

    private static func audiobook(
        matchingFileName fileName: String,
        in context: ModelContext
    ) -> Audiobook? {
        let descriptor = FetchDescriptor<Audiobook>()
        let audiobooks = (try? context.fetch(descriptor)) ?? []
        return audiobooks.first { $0.fileURL.lastPathComponent == fileName }
    }

    private static func removeAudiobook(
        _ audiobook: Audiobook,
        libraryManager: any LibraryManagerProtocol,
        in context: ModelContext
    ) {
        try? libraryManager.deleteAudiobookFile(at: audiobook.fileURL)
        context.delete(audiobook)
        try? context.save()
    }

    private static func discoverSupportedAudioFiles(in directoryURL: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var fileURLs: [URL] = []
        for case let fileURL as URL in enumerator {
            guard SupportedAudioExtension.isSupported(fileURL) else { continue }
            fileURLs.append(fileURL)
        }

        return fileURLs.sorted {
            $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending
        }
    }
}
#endif

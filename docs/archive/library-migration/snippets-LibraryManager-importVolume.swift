    func importVolume(from sourceURLs: [URL], suggestedTitle: String?) async throws -> AudiobookImportMetadata {
        guard !sourceURLs.isEmpty else {
            throw LibraryManagerError.fileNotFound
        }

        let sortedSources = sourceURLs.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        var combinedChapters: [ChapterImportMetadata] = []
        combinedChapters.reserveCapacity(sortedSources.count)

        var timelineOffset: TimeInterval = 0
        var primaryMetadata: AudiobookImportMetadata?
        var primaryFileURL: URL?

        for (index, sourceURL) in sortedSources.enumerated() {
            let metadata = try await importAudiobook(from: sourceURL)
            if index == 0 {
                primaryMetadata = metadata
                primaryFileURL = metadata.fileURL
            }

            let chapterTitle: String
            if sortedSources.count == 1 {
                chapterTitle = metadata.chapters.first?.title ?? metadata.title
            } else {
                chapterTitle = sourceURL.deletingPathExtension().lastPathComponent
            }

            combinedChapters.append(
                ChapterImportMetadata(
                    title: chapterTitle,
                    duration: metadata.duration,
                    startTime: timelineOffset,
                    orderIndex: index,
                    fileURL: metadata.fileURL
                )
            )
            timelineOffset += metadata.duration
        }

        guard let primaryMetadata, let primaryFileURL else {
            throw LibraryManagerError.importFailed
        }

        let resolvedTitle: String
        if let suggested = suggestedTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
           !suggested.isEmpty {
            resolvedTitle = suggested
        } else {
            resolvedTitle = primaryMetadata.title
        }

        return AudiobookImportMetadata(
            title: resolvedTitle,
            author: primaryMetadata.author,
            duration: timelineOffset,
            coverArtwork: primaryMetadata.coverArtwork,
            fileURL: primaryFileURL,
            chapters: combinedChapters
        )
    }

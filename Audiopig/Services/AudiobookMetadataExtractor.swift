//
//  AudiobookMetadataExtractor.swift
//  Audiopig
//

import AVFoundation
import Foundation

enum SupportedAudioExtension: String, CaseIterable, Sendable {
    case m4b
    case mp3

    static func isSupported(_ fileURL: URL) -> Bool {
        SupportedAudioExtension(rawValue: fileURL.pathExtension.lowercased()) != nil
    }
}

struct AudiobookMetadataExtractor: Sendable {
    private let titleIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierTitle,
        .iTunesMetadataSongName,
        .id3MetadataTitleDescription,
    ]

    private let authorIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierArtist,
        .iTunesMetadataArtist,
        .iTunesMetadataAlbumArtist,
        .id3MetadataLeadPerformer,
        .id3MetadataBand,
    ]

    private let artworkIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierArtwork,
        .iTunesMetadataCoverArt,
        .id3MetadataAttachedPicture,
    ]

    private let chapterTitleIdentifiers: [AVMetadataIdentifier] = [
        .commonIdentifierTitle,
        .id3MetadataTitleDescription,
        .iTunesMetadataTrackSubTitle,
    ]

    func extract(from fileURL: URL) async throws -> AudiobookImportMetadata {
        guard SupportedAudioExtension.isSupported(fileURL) else {
            throw LibraryManagerError.unsupportedFileFormat
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw LibraryManagerError.fileNotFound
        }

        let asset = AVURLAsset(
            url: fileURL,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )

        let isPlayable = try await asset.load(.isPlayable)
        guard isPlayable else {
            throw LibraryManagerError.unsupportedFileFormat
        }

        let durationCMTime = try await asset.load(.duration)
        let duration = CMTimeGetSeconds(durationCMTime)
        guard duration.isFinite, duration > 0 else {
            throw LibraryManagerError.metadataExtractionFailed
        }

        async let commonMetadata = asset.load(.commonMetadata)
        async let metadata = asset.load(.metadata)

        let resolvedCommonMetadata = try await commonMetadata
        let resolvedMetadata = try await metadata
        let allMetadataItems = resolvedCommonMetadata + resolvedMetadata

        let fallbackTitle = fileURL.deletingPathExtension().lastPathComponent
        let title = await firstStringValue(from: allMetadataItems, identifiers: titleIdentifiers) ?? fallbackTitle
        let author = await firstStringValue(from: allMetadataItems, identifiers: authorIdentifiers) ?? "Unknown Author"
        let coverArtwork = await extractArtwork(from: allMetadataItems)
        let chapters = try await extractChapters(
            from: asset,
            sourceFileURL: fileURL,
            totalDuration: duration,
            fallbackTitle: title
        )

        return AudiobookImportMetadata(
            title: title,
            author: author,
            duration: duration,
            coverArtwork: coverArtwork,
            fileURL: fileURL,
            chapters: chapters
        )
    }

    private func extractArtwork(from items: [AVMetadataItem]) async -> Data? {
        for identifier in artworkIdentifiers {
            let artworkItems = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)

            for item in artworkItems {
                if let data = try? await item.load(.dataValue), !data.isEmpty {
                    return data
                }
            }
        }

        return nil
    }

    private func extractChapters(
        from asset: AVURLAsset,
        sourceFileURL: URL,
        totalDuration: TimeInterval,
        fallbackTitle: String
    ) async throws -> [ChapterImportMetadata] {
        let locales = try await asset.load(.availableChapterLocales)
        var chapterGroups: [AVTimedMetadataGroup] = []

        if let locale = locales.first {
            chapterGroups = try await asset.loadChapterMetadataGroups(withTitleLocale: locale)
        }

        if chapterGroups.isEmpty, !locales.isEmpty {
            for locale in locales {
                let groups = try await asset.loadChapterMetadataGroups(withTitleLocale: locale)
                if !groups.isEmpty {
                    chapterGroups = groups
                    break
                }
            }
        }

        guard !chapterGroups.isEmpty else {
            return [
                ChapterImportMetadata(
                    title: fallbackTitle,
                    duration: totalDuration,
                    startTime: 0,
                    orderIndex: 0,
                    fileURL: sourceFileURL
                ),
            ]
        }

        var chapters: [ChapterImportMetadata] = []
        chapters.reserveCapacity(chapterGroups.count)

        for (index, group) in chapterGroups.enumerated() {
            let startTime = CMTimeGetSeconds(group.timeRange.start)
            let chapterDuration = CMTimeGetSeconds(group.timeRange.duration)

            guard startTime.isFinite, chapterDuration.isFinite, chapterDuration > 0 else {
                throw LibraryManagerError.metadataExtractionFailed
            }

            let chapterTitle = await firstStringValue(from: group.items, identifiers: chapterTitleIdentifiers)
                ?? "Chapter \(index + 1)"

            chapters.append(
                ChapterImportMetadata(
                    title: chapterTitle,
                    duration: chapterDuration,
                    startTime: startTime,
                    orderIndex: index,
                    fileURL: sourceFileURL
                )
            )
        }

        return chapters
    }

    private func firstStringValue(
        from items: [AVMetadataItem],
        identifiers: [AVMetadataIdentifier]
    ) async -> String? {
        for identifier in identifiers {
            let matchingItems = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier)

            for item in matchingItems {
                if let value = try? await item.load(.stringValue), !value.isEmpty {
                    return value
                }
            }
        }

        return nil
    }
}

//
//  WatchTransferManifestTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WatchTransferManifestTests: XCTestCase {

    func test_manifestRoundTrip() throws {
        let chapter = WatchChapterSummary(
            id: UUID(),
            title: "Chapter 1",
            startTime: 0,
            duration: 120,
            orderIndex: 0
        )
        let manifest = WatchTransferManifest(
            bookID: UUID(),
            title: "Test Book",
            author: "Author",
            duration: 3600,
            chapters: [chapter],
            fileByteCount: 1_024,
            sha256: "abc123",
            fileExtension: "m4b",
            thumbnailJPEG: nil,
            resumePosition: 42
        )

        let data = try WatchMessageCodec.encode(manifest)
        let decoded = try WatchMessageCodec.decode(WatchTransferManifest.self, from: data)

        XCTAssertEqual(decoded, manifest)
    }

    func test_localBooksPayloadRoundTrip() throws {
        let book = WatchBookSummary(
            id: UUID(),
            title: "Local",
            author: "Author",
            duration: 100,
            currentPlaybackTime: 10,
            lastPlayedAt: .now
        )
        let payload = WatchLocalBooksPayload(
            books: [book],
            usedBytes: 500,
            budgetBytes: WatchStorageBudget.defaultBudgetBytes
        )

        let data = try WatchMessageCodec.encode(payload)
        let decoded = try WatchMessageCodec.decode(WatchLocalBooksPayload.self, from: data)

        XCTAssertEqual(decoded, payload)
    }

    func test_watchSettingsFindBreaksPreferenceRoundTrip() throws {
        let settings = WatchSettingsSnapshot(
            artworkSkipGesturesEnabled: false,
            skipForwardSeconds: 30,
            skipBackwardSeconds: 15,
            findBreaksButtonHidden: false
        )

        let data = try WatchMessageCodec.encode(settings)
        let decoded = try WatchMessageCodec.decode(WatchSettingsSnapshot.self, from: data)

        XCTAssertFalse(decoded.effectiveFindBreaksButtonHidden)
    }

    func test_legacyWatchSettingsHideFindBreaksByDefault() throws {
        let legacyJSON = try XCTUnwrap("""
        {
          "artworkSkipGesturesEnabled": false,
          "skipForwardSeconds": 30,
          "skipBackwardSeconds": 15
        }
        """.data(using: .utf8))

        let decoded = try WatchMessageCodec.decode(
            WatchSettingsSnapshot.self,
            from: legacyJSON
        )

        XCTAssertTrue(decoded.effectiveFindBreaksButtonHidden)
    }

    func test_newWatchCommandsRoundTrip() throws {
        let bookID = UUID()
        let commands: [WatchCommand] = [
            .requestLocalBooks,
            .loadLocalBook(bookID: bookID, autoPlay: true),
            .deleteLocalBook(bookID: bookID),
            .syncLocalPlaybackPosition(bookID: bookID, time: 99.5),
            .acknowledgeLocalBooks(WatchLocalBooksPayload(books: [], usedBytes: 0, budgetBytes: 100)),
            .reportTransferIngestFailed(bookID: bookID, errorMessage: "Checksum mismatch"),
            .requestChapters,
            .analyzeLulls,
            .seekToLull(endTime: 123.5),
            .setWatchFindBreaksButtonHidden(false)
        ]

        for command in commands {
            let data = try WatchMessageCodec.encode(command)
            let decoded = try WatchMessageCodec.decode(WatchCommand.self, from: data)
            XCTAssertEqual(decoded, command)
        }
    }

    func test_localBooksPayloadSlimSyncCopyOmitsThumbnails() {
        let book = WatchBookSummary(
            id: UUID(),
            title: "Local",
            author: "Author",
            duration: 100,
            currentPlaybackTime: 10,
            lastPlayedAt: .now,
            thumbnailJPEG: Data([0xFF, 0xD8, 0xFF])
        )
        let payload = WatchLocalBooksPayload(
            books: [book],
            usedBytes: 500,
            budgetBytes: WatchStorageBudget.defaultBudgetBytes
        )
        let slim = payload.slimSyncCopy()
        XCTAssertEqual(slim.books.count, 1)
        XCTAssertNil(slim.books[0].thumbnailJPEG)
        XCTAssertEqual(slim.usedBytes, payload.usedBytes)
    }

    func test_recentBooksPayloadSlimSyncCopyOmitsThumbnails() {
        let book = WatchBookSummary(
            id: UUID(),
            title: "Recent",
            author: "Author",
            duration: 100,
            currentPlaybackTime: 10,
            lastPlayedAt: .now,
            thumbnailJPEG: Data(repeating: 0xAB, count: 512)
        )
        let payload = WatchRecentBooksPayload(books: [book])
        let slim = payload.slimSyncCopy()
        XCTAssertNil(slim.books[0].thumbnailJPEG)
    }

    func test_recentBooksMessageReplyPayloadFitsBudget() {
        let books = (0..<10).map { index in
            WatchBookSummary(
                id: UUID(),
                title: "Book \(index)",
                author: "Author",
                duration: 100,
                currentPlaybackTime: 10,
                lastPlayedAt: .now,
                thumbnailJPEG: Data(repeating: 0xCD, count: 8_192)
            )
        }
        let payload = WatchRecentBooksPayload(books: books)
        let reply = payload.messageReplyPayload(maxBytes: WatchApplicationContextBudget.messageMaxBytes)
        XCTAssertLessThanOrEqual(
            WatchApplicationContextBudget.encodedByteCount(reply),
            WatchApplicationContextBudget.messageMaxBytes
        )
    }

    func test_commandResultMessageReplyPayloadStripsArtworkAndChapters() throws {
        let snapshot = WatchPlaybackSnapshot(
            revision: 1,
            bookID: UUID(),
            title: "Title",
            author: "Author",
            chapterTitle: "Chapter",
            playbackState: .playing,
            playbackSpeed: 1,
            skipForwardSeconds: 30,
            skipBackwardSeconds: 15,
            chapterIndex: 0,
            chapterCount: 1,
            chapterElapsed: 0,
            chapterDuration: 100,
            chapterProgress: 0,
            globalCurrentTime: 0,
            globalDuration: 100,
            systemVolume: 0.5,
            source: .remote,
            artworkJPEG: Data(repeating: 0xAB, count: 50_000)
        )
        let chapters = WatchChaptersPayload(
            bookID: snapshot.bookID!,
            chapters: (0..<200).map { index in
                WatchChapterSummary(
                    id: UUID(),
                    title: "Chapter \(index)",
                    startTime: TimeInterval(index * 60),
                    duration: 60,
                    orderIndex: index
                )
            }
        )
        let result = WatchCommandResult.ok(snapshot: snapshot, chapters: chapters)
        let trimmed = result.messageReplyPayload(maxBytes: WatchApplicationContextBudget.messageMaxBytes)
        XCTAssertLessThanOrEqual(
            WatchApplicationContextBudget.encodedByteCount(trimmed),
            WatchApplicationContextBudget.messageMaxBytes
        )
        XCTAssertNil(trimmed.snapshot?.artworkJPEG)
    }

    func test_overallPercentCombinesPhases() {
        let preparing = WatchTransferProgress(bookID: UUID(), phase: .preparing, fractionCompleted: 0.5)
        XCTAssertEqual(preparing.overallPercent, 4)

        let sending = WatchTransferProgress(bookID: UUID(), phase: .transferring, fractionCompleted: 0.5)
        XCTAssertEqual(sending.overallPercent, 52)

        let installing = WatchTransferProgress(bookID: UUID(), phase: .installing)
        XCTAssertEqual(installing.overallPercent, 95)
    }

    func test_wireTransferCopyOmitsThumbnail() {
        let thumbnail = Data([0xFF, 0xD8, 0xFF])
        let manifest = WatchTransferManifest(
            bookID: UUID(),
            title: "Test",
            author: "Author",
            duration: 60,
            chapters: [],
            fileByteCount: 100,
            sha256: "abc",
            fileExtension: "m4b",
            thumbnailJPEG: thumbnail
        )
        XCTAssertEqual(manifest.wireTransferCopy().thumbnailJPEG, nil)
        XCTAssertEqual(manifest.wireTransferCopy().bookID, manifest.bookID)
    }
}

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

    func test_newWatchCommandsRoundTrip() throws {
        let bookID = UUID()
        let commands: [WatchCommand] = [
            .requestLocalBooks,
            .loadLocalBook(bookID: bookID, autoPlay: true),
            .deleteLocalBook(bookID: bookID),
            .syncLocalPlaybackPosition(bookID: bookID, time: 99.5),
            .acknowledgeLocalBooks(WatchLocalBooksPayload(books: [], usedBytes: 0, budgetBytes: 100)),
            .reportTransferIngestFailed(bookID: bookID, errorMessage: "Checksum mismatch"),
            .analyzeLulls,
            .seekToLull(endTime: 123.5)
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

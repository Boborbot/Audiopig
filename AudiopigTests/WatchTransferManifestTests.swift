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
            .acknowledgeLocalBooks(WatchLocalBooksPayload(books: [], usedBytes: 0, budgetBytes: 100))
        ]

        for command in commands {
            let data = try WatchMessageCodec.encode(command)
            let decoded = try WatchMessageCodec.decode(WatchCommand.self, from: data)
            XCTAssertEqual(decoded, command)
        }
    }
}

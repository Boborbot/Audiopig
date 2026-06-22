//
//  LibraryBackupServiceTests.swift
//  AudiopigTests
//

import SwiftData
import XCTest
@testable import Audiopig

final class LibraryBackupServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: LibraryBackupService!
    private var tempFileURL: URL!

    override func setUpWithError() throws {
        container = try AudiopigModelContainer.make(isStoredInMemoryOnly: true)
        context = ModelContext(container)
        service = LibraryBackupService()

        tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-test-\(UUID().uuidString).m4b")
        try Data(repeating: 0xAB, count: 512_000).write(to: tempFileURL)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempFileURL)
        container = nil
        context = nil
        service = nil
    }

    func testApplyManifestRestoresPlaybackProgress() throws {
        let book = Audiobook(
            title: "Dune",
            author: "Frank Herbert",
            duration: 3_600,
            currentPlaybackTime: 0,
            fileURL: tempFileURL
        )
        context.insert(book)
        try context.save()

        let manifest = LibraryBackupManifest(
            books: [
                LibraryBackupBookEntry(
                    fingerprint: LibraryBackupFingerprint(fileName: tempFileURL.lastPathComponent, fileSize: 512_000, duration: 3_600),
                    title: "Dune",
                    author: "Frank Herbert",
                    currentPlaybackTime: 1_500,
                    lastPlaybackSpeed: 1.5,
                    lastPlayedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    isManuallyFinished: false,
                    bookmarks: [
                        LibraryBackupBookmarkEntry(title: "Spice", note: "", timestamp: 120)
                    ]
                ),
            ],
            folders: []
        )

        let data = try LibraryBackupManifestCodec.encode(manifest)
        let backupURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apply-test-\(UUID().uuidString).json")
        try data.write(to: backupURL)
        defer { try? FileManager.default.removeItem(at: backupURL) }

        let result = try service.applyManifest(at: backupURL, in: context)

        XCTAssertEqual(result.restoredBooks, 1)
        XCTAssertEqual(result.unmatchedEntries, 0)
        XCTAssertEqual(book.currentPlaybackTime, 1_500, accuracy: 0.01)
        XCTAssertEqual(book.lastPlaybackSpeed, 1.5)
        XCTAssertEqual(book.bookmarks.count, 1)
        XCTAssertEqual(book.bookmarks.first?.title, "Spice")
    }

    func testApplyManifestDoesNotDecreaseProgress() throws {
        let book = Audiobook(
            title: "Dune",
            author: "Frank Herbert",
            duration: 3_600,
            currentPlaybackTime: 2_000,
            fileURL: tempFileURL
        )
        context.insert(book)
        try context.save()

        let manifest = LibraryBackupManifest(
            books: [
                LibraryBackupBookEntry(
                    fingerprint: LibraryBackupFingerprint(fileName: tempFileURL.lastPathComponent, fileSize: 512_000, duration: 3_600),
                    title: "Dune",
                    author: "Frank Herbert",
                    currentPlaybackTime: 500,
                    lastPlaybackSpeed: nil,
                    lastPlayedAt: nil,
                    isManuallyFinished: false,
                    bookmarks: []
                ),
            ],
            folders: []
        )

        let data = try LibraryBackupManifestCodec.encode(manifest)
        let backupURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("apply-test-\(UUID().uuidString).json")
        try data.write(to: backupURL)
        defer { try? FileManager.default.removeItem(at: backupURL) }

        _ = try service.applyManifest(at: backupURL, in: context)
        XCTAssertEqual(book.currentPlaybackTime, 2_000, accuracy: 0.01)
    }
}

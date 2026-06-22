//
//  LibraryBackupManifestTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class LibraryBackupManifestTests: XCTestCase {

    private let sampleManifest = LibraryBackupManifest(
        exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
        books: [
            LibraryBackupBookEntry(
                fingerprint: LibraryBackupFingerprint(fileName: "dune.m4b", fileSize: 500_000, duration: 3_600),
                title: "Dune",
                author: "Frank Herbert",
                currentPlaybackTime: 1_200,
                lastPlaybackSpeed: 1.25,
                lastPlayedAt: Date(timeIntervalSince1970: 1_700_000_100),
                isManuallyFinished: false,
                bookmarks: [
                    LibraryBackupBookmarkEntry(title: "Spice", note: "First mention", timestamp: 100)
                ]
            ),
        ],
        folders: [
            LibraryBackupFolderEntry(
                title: "Sci-Fi",
                bookFingerprints: [
                    LibraryBackupFingerprint(fileName: "dune.m4b", fileSize: 500_000, duration: 3_600)
                ]
            ),
        ]
    )

    func testEncodeDecodeRoundTrip() throws {
        let data = try LibraryBackupManifestCodec.encode(sampleManifest)
        let decoded = try LibraryBackupManifestCodec.decode(from: data)
        XCTAssertEqual(decoded, sampleManifest)
    }

    func testRejectsUnsupportedFormatVersion() throws {
        let legacy = LibraryBackupManifest(formatVersion: 99, books: [], folders: [])
        let data = try LibraryBackupManifestCodec.encode(legacy)

        XCTAssertThrowsError(try LibraryBackupManifestCodec.decode(from: data)) { error in
            XCTAssertEqual(error as? LibraryBackupManifestError, .unsupportedFormatVersion(99))
        }
    }

    func testMergePolicyNeverDecreasesPlaybackTime() {
        XCTAssertEqual(LibraryBackupMergePolicy.mergedPlaybackTime(existing: 500, imported: 200), 500)
        XCTAssertEqual(LibraryBackupMergePolicy.mergedPlaybackTime(existing: 100, imported: 400), 400)
    }

    func testMatcherPairsByFingerprint() {
        let library = [
            AudiobookFingerprint(normalizedFileName: "other.m4b", fileSize: 1, duration: 100),
            AudiobookFingerprint(normalizedFileName: "dune.m4b", fileSize: 500_000, duration: 3_600),
        ]

        let matches = LibraryBackupMatcher.match(manifest: sampleManifest, libraryFingerprints: library)
        XCTAssertEqual(matches.count, 1)
        XCTAssertEqual(matches[0].entry.title, "Dune")
        XCTAssertEqual(matches[0].libraryIndex, 1)
    }

    func testMatcherCountsUnmatchedEntries() {
        let library = [
            AudiobookFingerprint(normalizedFileName: "other.m4b", fileSize: 1, duration: 100),
        ]
        XCTAssertEqual(
            LibraryBackupMatcher.unmatchedEntryCount(manifest: sampleManifest, libraryFingerprints: library),
            1
        )
    }

    func testFingerprintMatchesWithinDurationTolerance() {
        let left = AudiobookFingerprint(normalizedFileName: "book.m4b", fileSize: 100, duration: 3_600)
        let right = AudiobookFingerprint(normalizedFileName: "book.m4b", fileSize: 100, duration: 3_600.5)
        XCTAssertTrue(left.matches(right))
    }
}

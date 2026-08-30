//
//  LibraryFileReclamationTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class LibraryFileReclamationTests: XCTestCase {

    private let library = URL(fileURLWithPath: "/tmp/Audiopig/Library", isDirectory: true)

    func test_filesToRemove_skipsReferencedAndExternalPaths() {
        let keep = library.appendingPathComponent("keep.mp3")
        let orphan = library.appendingPathComponent("orphan.mp3")
        let outside = URL(fileURLWithPath: "/tmp/other/book.mp3")
        let duplicateOrphan = library.appendingPathComponent("orphan.mp3")

        let removed = LibraryFileReclamation.filesToRemove(
            candidates: [keep, orphan, outside, duplicateOrphan],
            referencedPaths: [keep.standardizedFileURL.path],
            libraryDirectoryURL: library
        )

        XCTAssertEqual(removed.map(\.lastPathComponent), ["orphan.mp3"])
    }

    func test_filesToRemove_doesNotTreatSimilarlyPrefixedDirectoryAsLibrary() {
        let otherLibrary = URL(fileURLWithPath: "/tmp/Audiopig/LibraryBackup/book.mp3")
        let removed = LibraryFileReclamation.filesToRemove(
            candidates: [otherLibrary],
            referencedPaths: [],
            libraryDirectoryURL: library
        )
        XCTAssertTrue(removed.isEmpty)
    }
}

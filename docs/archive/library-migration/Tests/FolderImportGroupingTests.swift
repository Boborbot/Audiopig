//
//  FolderImportGroupingTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class FolderImportGroupingTests: XCTestCase {

    func testSingleFileAtRoot() {
        let groups = FolderImportGrouping.group(relativeFilePaths: ["book.m4b"])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].relativeDirectory, "")
        XCTAssertEqual(groups[0].fileNames, ["book.m4b"])
    }

    func testMultipleMp3sInSameFolderBecomeOneVolume() {
        let groups = FolderImportGrouping.group(relativeFilePaths: [
            "chapter02.mp3",
            "chapter01.mp3",
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].fileNames, ["chapter01.mp3", "chapter02.mp3"])
    }

    func testNestedBookFolderGroupsTogether() {
        let groups = FolderImportGrouping.group(relativeFilePaths: [
            "Author/Book/part01.mp3",
            "Author/Book/part02.mp3",
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].relativeDirectory, "Author/Book")
        XCTAssertEqual(groups[0].fileNames.count, 2)
    }

    func testSiblingDiscFoldersStaySeparate() {
        let groups = FolderImportGrouping.group(relativeFilePaths: [
            "SomeBook/CD1/track01.mp3",
            "SomeBook/CD2/track01.mp3",
        ])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.map(\.relativeDirectory)), ["SomeBook/CD1", "SomeBook/CD2"])
    }

    func testLooseM4bFilesAtRootAreSeparateBooks() {
        let groups = FolderImportGrouping.group(relativeFilePaths: ["a.m4b", "b.m4b"])
        XCTAssertEqual(groups.count, 2)
        XCTAssertTrue(groups.allSatisfy { $0.fileNames.count == 1 })
    }

    func testIgnoresUnsupportedExtensions() {
        let groups = FolderImportGrouping.group(relativeFilePaths: [
            "notes.txt",
            "book.m4b",
        ])
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].fileNames, ["book.m4b"])
    }

    func testSuggestedTitleUsesFolderNameForMultiFileVolume() {
        let group = FolderImportGroup(relativeDirectory: "Author/Book Title", fileNames: ["01.mp3", "02.mp3"])
        XCTAssertEqual(
            FolderImportGrouping.suggestedTitle(for: group, primaryFileTitle: "01"),
            "Book Title"
        )
    }

    func testSuggestedTitleFallsBackToPrimaryFileTitle() {
        let group = FolderImportGroup(relativeDirectory: "", fileNames: ["My Book.m4b"])
        XCTAssertEqual(
            FolderImportGrouping.suggestedTitle(for: group, primaryFileTitle: "Embedded Title"),
            "Embedded Title"
        )
    }
}

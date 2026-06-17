//
//  BookmarkExportServiceTests.swift
//  AudiopigTests
//

import SwiftData
import XCTest
@testable import Audiopig

final class BookmarkExportServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        container = try AudiopigModelContainer.make(isStoredInMemoryOnly: true)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        container = nil
        context = nil
    }

    func testGenerateTextIncludesBookMetadataAndBookmarkRows() throws {
        let book = Audiobook(
            title: "Dune",
            author: "Frank Herbert",
            duration: 3_661,
            fileURL: URL(fileURLWithPath: "/tmp/dune.m4b")
        )
        let bookmark = Bookmark(title: "Spice", note: "First mention", timestamp: 125)
        book.bookmarks = [bookmark]
        context.insert(book)
        try context.save()

        let text = BookmarkExportService.generateText(for: book, bookmarks: [bookmark])

        XCTAssertTrue(text.contains("AUDIOBOOK BOOKMARKS"))
        XCTAssertTrue(text.contains("Book:     Dune"))
        XCTAssertTrue(text.contains("Author:   Frank Herbert"))
        XCTAssertTrue(text.contains("Length:   1:01:01"))
        XCTAssertTrue(text.contains("Spice"))
        XCTAssertTrue(text.contains("First mention"))
        XCTAssertTrue(text.contains("2:05"))
    }

    func testExportReturnsNilWhenBookHasNoBookmarks() throws {
        let book = Audiobook(
            title: "Empty",
            author: "Nobody",
            duration: 60,
            fileURL: URL(fileURLWithPath: "/tmp/empty.mp3")
        )
        context.insert(book)
        try context.save()

        XCTAssertNil(try BookmarkExportService.export(book))
    }
}

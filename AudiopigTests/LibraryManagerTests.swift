//
//  LibraryManagerTests.swift
//  AudiopigTests
//

import SwiftData
import XCTest
@testable import Audiopig

@MainActor
final class LibraryManagerTests: XCTestCase {

    private var tempDirectory: URL!
    private var manager: LibraryManager!
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUpWithError() throws {
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AudiopigLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        manager = try LibraryManager(libraryDirectoryURL: tempDirectory)
        container = try AudiopigModelContainer.make(isStoredInMemoryOnly: true)
        context = ModelContext(container)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        manager = nil
        context = nil
        container = nil
    }

    func test_copyIntoLibrary_copiesExternalFileAndLeavesSource() throws {
        let source = FileManager.default.temporaryDirectory
            .appendingPathComponent("source-\(UUID().uuidString).mp3")
        try Data("audiopig-source".utf8).write(to: source)
        defer { try? FileManager.default.removeItem(at: source) }

        let copied = try manager.copyIntoLibrary(from: source)

        XCTAssertEqual(copied.deletingLastPathComponent(), tempDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copied.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: copied), Data("audiopig-source".utf8))
    }

    func test_copyIntoLibrary_returnsExistingLibraryFileWithoutDuplicating() throws {
        let existing = writeDummyFile(named: "already-there.mp3")
        let copied = try manager.copyIntoLibrary(from: existing)
        XCTAssertEqual(copied.standardizedFileURL, existing.standardizedFileURL)

        let files = try FileManager.default.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.filter { $0.lastPathComponent.hasPrefix("already-there") }.count, 1)
    }

    func test_deleteUnreferencedFiles_removesOrphansOnly() throws {
        let keepURL = writeDummyFile(named: "keep.mp3")
        let orphanURL = writeDummyFile(named: "orphan.mp3")
        let outsideURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("outside-\(UUID().uuidString).mp3")
        try Data("x".utf8).write(to: outsideURL)
        defer { try? FileManager.default.removeItem(at: outsideURL) }

        _ = persistBook(title: "Keep", fileURL: keepURL)

        manager.deleteUnreferencedFiles([keepURL, orphanURL, outsideURL], in: context)

        XCTAssertTrue(FileManager.default.fileExists(atPath: keepURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: orphanURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: outsideURL.path))
    }

    func test_deletingManyBooksLeavesUnrelatedBookAndFile() throws {
        let keeperURL = writeDummyFile(named: "keeper.mp3")
        let keeper = persistBook(title: "Keeper", fileURL: keeperURL)

        var doomedURLs: [URL] = []
        for index in 0..<40 {
            let url = writeDummyFile(named: "doomed-\(index).mp3")
            doomedURLs.append(url)
            let book = persistBook(title: "Doomed \(index)", fileURL: url)
            context.delete(book)
        }
        try context.save()
        manager.deleteUnreferencedFiles(doomedURLs + [keeperURL], in: context)

        let remaining = try context.fetch(FetchDescriptor<Audiobook>())
        XCTAssertEqual(remaining.map(\.id), [keeper.id])
        XCTAssertTrue(FileManager.default.fileExists(atPath: keeperURL.path))
        for url in doomedURLs {
            XCTAssertFalse(FileManager.default.fileExists(atPath: url.path), url.lastPathComponent)
        }
    }

    private func writeDummyFile(named name: String) -> URL {
        let url = tempDirectory.appendingPathComponent(name)
        try! Data("audiopig-test".utf8).write(to: url)
        return url
    }

    private func persistBook(title: String, fileURL: URL) -> Audiobook {
        let metadata = AudiobookImportMetadata(
            title: title,
            author: "Author",
            duration: 60,
            coverArtwork: nil,
            fileURL: fileURL,
            chapters: [
                ChapterImportMetadata(
                    title: title,
                    duration: 60,
                    startTime: 0,
                    orderIndex: 0,
                    fileURL: fileURL
                )
            ]
        )
        return try! manager.persist(metadata: metadata, in: context)
    }
}

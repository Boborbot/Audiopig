//
//  StatsViewModelTests.swift
//  AudiopigTests
//

import SwiftData
import XCTest
@testable import Audiopig

/// Keeps `@MainActor` view models alive through XCTest teardown to avoid Swift 6 deinit crashes in the host app.
@MainActor
private enum StatsViewModelTestRetention {
    static var viewModels: [StatsViewModel] = []
}

@MainActor
final class StatsViewModelTests: XCTestCase {

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

    func testDeleteAllStatsRemovesFinishedRecords() throws {
        let record = FinishedRecord(
            audiobookID: UUID(),
            title: "Done",
            author: "Author",
            totalSeconds: 3600,
            listenedSeconds: 120,
            finishedAt: .now,
            chapterCount: 1,
            wasManuallyMarked: false
        )
        context.insert(record)
        try context.save()

        let viewModel = StatsViewModel(modelContext: context)
        StatsViewModelTestRetention.viewModels.append(viewModel)
        viewModel.refresh()
        XCTAssertEqual(viewModel.finishedBooksCount, 1)

        viewModel.deleteAllStats()

        let remaining = try context.fetch(FetchDescriptor<FinishedRecord>())
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(viewModel.finishedBooksCount, 0)
    }

    func testFinishedInLibraryBookDoesNotDoubleCountListeningTime() throws {
        let audiobook = Audiobook(
            title: "Done",
            author: "Author",
            duration: 7_200,
            currentPlaybackTime: 7_200,
            isManuallyFinished: true,
            fileURL: URL(fileURLWithPath: "/tmp/book.m4b")
        )
        audiobook.accumulatedListeningSeconds = 3_600
        context.insert(audiobook)

        let record = FinishedRecord(
            audiobookID: audiobook.id,
            title: "Done",
            author: "Author",
            totalSeconds: 7_200,
            listenedSeconds: 3_600,
            finishedAt: .now,
            chapterCount: 1,
            wasManuallyMarked: false
        )
        context.insert(record)
        try context.save()

        let viewModel = StatsViewModel(modelContext: context)
        StatsViewModelTestRetention.viewModels.append(viewModel)
        viewModel.refresh()

        XCTAssertEqual(viewModel.totalListenedSeconds, 3_600, accuracy: 0.01)
        XCTAssertEqual(viewModel.finishedListenedSeconds, 3_600, accuracy: 0.01)
    }

    func testDeleteAllStatsClearsAccumulatedListeningTime() throws {
        let addedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let lastPlayedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let audiobook = Audiobook(
            title: "In Progress",
            author: "Author",
            duration: 3600,
            currentPlaybackTime: 600,
            isManuallyFinished: true,
            fileURL: URL(fileURLWithPath: "/tmp/book.m4b")
        )
        audiobook.accumulatedListeningSeconds = 5400
        audiobook.addedAt = addedAt
        audiobook.lastPlayedAt = lastPlayedAt
        context.insert(audiobook)
        try context.save()

        let viewModel = StatsViewModel(modelContext: context)
        StatsViewModelTestRetention.viewModels.append(viewModel)
        viewModel.refresh()
        XCTAssertEqual(viewModel.totalListenedSeconds, 5400, accuracy: 0.01)

        viewModel.deleteAllStats()

        XCTAssertEqual(audiobook.accumulatedListeningSeconds, 0, accuracy: 0.01)
        XCTAssertEqual(audiobook.currentPlaybackTime, 600, accuracy: 0.01)
        XCTAssertEqual(audiobook.lastPlayedAt, lastPlayedAt)
        XCTAssertEqual(audiobook.addedAt, addedAt)
        XCTAssertTrue(audiobook.isManuallyFinished)
        XCTAssertEqual(viewModel.totalListenedSeconds, 0, accuracy: 0.01)
    }

    func testRefreshComputesAverageDailyFromEarliestLibraryDate() throws {
        let addedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let audiobook = Audiobook(
            title: "Long Listener",
            author: "Author",
            duration: 36_000,
            currentPlaybackTime: 600,
            fileURL: URL(fileURLWithPath: "/tmp/book.m4b")
        )
        audiobook.accumulatedListeningSeconds = 10 * 3_600
        audiobook.addedAt = addedAt
        context.insert(audiobook)
        try context.save()

        StatsListeningHistory.adoptEarlierFirstListenDateIfNeeded(.now)

        let viewModel = StatsViewModel(modelContext: context)
        StatsViewModelTestRetention.viewModels.append(viewModel)
        viewModel.refresh()

        XCTAssertEqual(viewModel.totalListenedSeconds, 10 * 3_600, accuracy: 0.01)
        XCTAssertLessThan(viewModel.averageDailyListenedSeconds, viewModel.totalListenedSeconds)
        XCTAssertGreaterThan(viewModel.averageDailyListenedSeconds, 0)
    }
}

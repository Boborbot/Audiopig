//
//  StatsViewModelTests.swift
//  AudiopigTests
//

import SwiftData
import XCTest
@testable import Audiopig

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
        XCTAssertEqual(viewModel.finishedBooksCount, 1)

        viewModel.deleteAllStats()

        let remaining = try context.fetch(FetchDescriptor<FinishedRecord>())
        XCTAssertTrue(remaining.isEmpty)
        XCTAssertEqual(viewModel.finishedBooksCount, 0)
    }
}

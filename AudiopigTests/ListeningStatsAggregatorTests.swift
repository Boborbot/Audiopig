//
//  ListeningStatsAggregatorTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class ListeningStatsAggregatorTests: XCTestCase {

    func testInLibraryFinishedBookCountsListeningOnce() {
        let bookID = UUID()
        let books = [
            ListeningStatsBookInput(
                id: bookID,
                accumulatedListeningSeconds: 3_600,
                isFinished: true
            )
        ]
        let records = [
            ListeningStatsFinishRecordInput(
                audiobookID: bookID,
                listenedSeconds: 3_600,
                finishedAt: .now
            )
        ]

        let totals = ListeningStatsAggregator.compute(books: books, records: records)

        XCTAssertEqual(totals.totalListenedSeconds, 3_600, accuracy: 0.01)
        XCTAssertEqual(totals.finishedBooksCount, 1)
        XCTAssertEqual(totals.finishedListenedSeconds, 3_600, accuracy: 0.01)
    }

    func testDeletedFinishedBookUsesFinishSnapshotOnly() {
        let deletedBookID = UUID()
        let records = [
            ListeningStatsFinishRecordInput(
                audiobookID: deletedBookID,
                listenedSeconds: 7_200,
                finishedAt: .now
            )
        ]

        let totals = ListeningStatsAggregator.compute(books: [], records: records)

        XCTAssertEqual(totals.totalListenedSeconds, 7_200, accuracy: 0.01)
        XCTAssertEqual(totals.finishedBooksCount, 1)
        XCTAssertEqual(totals.finishedListenedSeconds, 7_200, accuracy: 0.01)
    }

    func testDuplicateFinishRecordsForDeletedBookCountOnce() {
        let deletedBookID = UUID()
        let older = Date(timeIntervalSince1970: 1_700_000_000)
        let newer = Date(timeIntervalSince1970: 1_800_000_000)
        let records = [
            ListeningStatsFinishRecordInput(
                audiobookID: deletedBookID,
                listenedSeconds: 3_600,
                finishedAt: older
            ),
            ListeningStatsFinishRecordInput(
                audiobookID: deletedBookID,
                listenedSeconds: 9_999,
                finishedAt: newer
            )
        ]

        let totals = ListeningStatsAggregator.compute(books: [], records: records)

        XCTAssertEqual(totals.totalListenedSeconds, 9_999, accuracy: 0.01)
        XCTAssertEqual(totals.finishedBooksCount, 1)
    }

    func testInProgressAndDeletedFinishedBooksCombineWithoutOverlap() {
        let inProgressID = UUID()
        let deletedID = UUID()
        let books = [
            ListeningStatsBookInput(
                id: inProgressID,
                accumulatedListeningSeconds: 1_800,
                isFinished: false
            )
        ]
        let records = [
            ListeningStatsFinishRecordInput(
                audiobookID: deletedID,
                listenedSeconds: 2_400,
                finishedAt: .now
            )
        ]

        let totals = ListeningStatsAggregator.compute(books: books, records: records)

        XCTAssertEqual(totals.totalListenedSeconds, 4_200, accuracy: 0.01)
        XCTAssertEqual(totals.finishedBooksCount, 1)
        XCTAssertEqual(totals.finishedListenedSeconds, 2_400, accuracy: 0.01)
    }
}

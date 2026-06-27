//
//  StatsListeningHistoryTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class StatsListeningHistoryTests: XCTestCase {

    func test_averageDailySeconds_dividesByInclusiveDaySpan() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstListen = Date(timeIntervalSince1970: 0)
        let now = calendar.date(byAdding: .day, value: 6, to: firstListen)!

        let average = StatsListeningHistory.averageDailySeconds(
            totalListenedSeconds: 7 * 3_600,
            firstListen: firstListen,
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(average, 3_600, accuracy: 0.01)
    }

    func test_earliestFirstListenDate_prefersLibraryHistoryOverRecentTrackedAnchor() {
        let tracked = Date(timeIntervalSince1970: 1_800_000_000)
        let addedAt = Date(timeIntervalSince1970: 1_700_000_000)

        let earliest = StatsListeningHistory.earliestFirstListenDate(
            trackedFirstListen: tracked,
            bookAddedDates: [addedAt],
            finishedListeningDates: []
        )

        XCTAssertEqual(earliest, addedAt)
    }

    func test_averageDailySeconds_withoutFirstListen_returnsZero() {
        XCTAssertEqual(
            StatsListeningHistory.averageDailySeconds(
                totalListenedSeconds: 3_600,
                firstListen: nil
            ),
            0,
            accuracy: 0.01
        )
    }

    func test_makeWeeklySlices_limitsVisibleBooksAndGroupsRemainderAsOther() {
        let first = UUID()
        let second = UUID()
        let third = UUID()
        let secondsByBookID: [UUID: TimeInterval] = [
            first: 3_600,
            second: 1_800,
            third: 900
        ]

        let slices = StatsListeningHistory.makeWeeklySlices(
            secondsByBookID: secondsByBookID,
            weeklyTotalSeconds: 6_300,
            titleForBook: { id in
                switch id {
                case first: return "Alpha"
                case second: return "Beta"
                case third: return "Gamma"
                default: return "Unknown"
                }
            },
            maxBookSlices: 2
        )

        XCTAssertEqual(slices.count, 3)
        XCTAssertEqual(slices[0].title, "Alpha")
        XCTAssertEqual(slices[1].title, "Beta")
        XCTAssertEqual(slices[2].title, "Other")
        XCTAssertEqual(slices[2].seconds, 900, accuracy: 0.01)
    }

    func test_makeWeeklySlices_addsUnknownSliceForUnallocatedWeeklyTime() {
        let bookID = UUID()
        let slices = StatsListeningHistory.makeWeeklySlices(
            secondsByBookID: [bookID: 1_800],
            weeklyTotalSeconds: 3_600,
            titleForBook: { _ in "Tracked Book" }
        )

        XCTAssertEqual(slices.count, 2)
        XCTAssertEqual(slices[0].title, "Tracked Book")
        XCTAssertEqual(slices[0].seconds, 1_800, accuracy: 0.01)
        XCTAssertEqual(slices[1].title, "Unknown")
        XCTAssertEqual(slices[1].seconds, 1_800, accuracy: 0.01)
        XCTAssertEqual(slices[1].paletteIndex, StatsChartPalette.unknownPaletteIndex)
        XCTAssertEqual(
            StatsListeningHistory.weeklyTotalSeconds(from: slices),
            3_600,
            accuracy: 0.01
        )
    }

    func test_makeWeeklySlices_assignsDistinctPaletteIndices() {
        let books = (0..<4).map { _ in UUID() }
        var secondsByBookID: [UUID: TimeInterval] = [:]
        for (index, id) in books.enumerated() {
            secondsByBookID[id] = TimeInterval((4 - index) * 1_000)
        }

        let slices = StatsListeningHistory.makeWeeklySlices(
            secondsByBookID: secondsByBookID,
            weeklyTotalSeconds: 10_000,
            titleForBook: { _ in "Book" }
        )

        let bookSliceIndices = slices
            .filter { $0.title != "Unknown" }
            .map(\.paletteIndex)
        XCTAssertEqual(Set(bookSliceIndices).count, bookSliceIndices.count)
    }

    func test_weeklyTotalSeconds_sumsSliceValues() {
        let slices = [
            StatsListeningHistory.WeeklyBookSlice(
                id: UUID(),
                title: "One",
                seconds: 1_800,
                paletteIndex: 0
            ),
            StatsListeningHistory.WeeklyBookSlice(
                id: UUID(),
                title: "Two",
                seconds: 600,
                paletteIndex: 1
            )
        ]

        XCTAssertEqual(
            StatsListeningHistory.weeklyTotalSeconds(from: slices),
            2_400,
            accuracy: 0.01
        )
    }
}

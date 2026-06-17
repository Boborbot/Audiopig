//
//  LibrarySorterTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class LibrarySorterTests: XCTestCase {

    private let day1 = Date(timeIntervalSince1970: 1_700_000_000)
    private let day2 = Date(timeIntervalSince1970: 1_700_086_400)
    private let day3 = Date(timeIntervalSince1970: 1_700_172_800)
    private let calendar = Calendar(identifier: .gregorian)

    func test_recentlyListened_putsPlayedBooksFirstByRecency() {
        let books = [
            candidate(title: "Old Play", lastPlayedAt: day1, addedAt: day1),
            candidate(title: "New Play", lastPlayedAt: day3, addedAt: day1),
            candidate(title: "Never", lastPlayedAt: nil, addedAt: day3),
            candidate(title: "Also Never", lastPlayedAt: nil, addedAt: day2),
        ]

        let sorted = LibrarySorter.sorted(books, by: .recentlyListened).map(\.title)

        XCTAssertEqual(sorted, ["New Play", "Old Play", "Also Never", "Never"])
    }

    func test_dateAdded_sortsNewestFirst() {
        let books = [
            candidate(title: "A", addedAt: day1),
            candidate(title: "B", addedAt: day3),
            candidate(title: "C", addedAt: day2),
        ]

        let sorted = LibrarySorter.sorted(books, by: .dateAdded).map(\.title)
        XCTAssertEqual(sorted, ["B", "C", "A"])
    }

    func test_dateAdded_groupsByCalendarDay_thenSortsNewestTimeFirst() {
        let baseDay = calendar.startOfDay(for: day2)
        let morning = baseDay.addingTimeInterval(60 * 60 * 9)   // 09:00
        let evening = baseDay.addingTimeInterval(60 * 60 * 18)  // 18:00

        let books = [
            candidate(title: "Morning", addedAt: morning),
            candidate(title: "Evening", addedAt: evening),
        ]

        let sorted = LibrarySorter.sorted(books, by: .dateAdded).map(\.title)
        XCTAssertEqual(sorted, ["Evening", "Morning"])
    }

    func test_timeAdded_sortsByTimeOfDayNewestFirst_thenNewerDay() {
        let day2Start = calendar.startOfDay(for: day2)
        let day3Start = calendar.startOfDay(for: day3)

        let nineAM_day2 = day2Start.addingTimeInterval(60 * 60 * 9) // 09:00
        let onePM_day3 = day3Start.addingTimeInterval(60 * 60 * 13) // 13:00
        let nineAM_day3 = day3Start.addingTimeInterval(60 * 60 * 9) // 09:00

        let books = [
            candidate(title: "09:00 day2", addedAt: nineAM_day2),
            candidate(title: "13:00 day3", addedAt: onePM_day3),
            candidate(title: "09:00 day3", addedAt: nineAM_day3),
        ]

        let sorted = LibrarySorter.sorted(books, by: .timeAdded).map(\.title)
        XCTAssertEqual(sorted, ["13:00 day3", "09:00 day3", "09:00 day2"])
    }

    func test_title_sortsAlphabeticallyAscending() {
        let books = [
            candidate(title: "Zebra"),
            candidate(title: "alpha"),
            candidate(title: "Beta"),
        ]

        let sorted = LibrarySorter.sorted(books, by: .title, direction: .ascending).map(\.title)
        XCTAssertEqual(sorted, ["alpha", "Beta", "Zebra"])
    }

    func test_title_sortsReverseAlphabeticallyDescending() {
        let books = [
            candidate(title: "Zebra"),
            candidate(title: "alpha"),
            candidate(title: "Beta"),
        ]

        let sorted = LibrarySorter.sorted(books, by: .title, direction: .descending).map(\.title)
        XCTAssertEqual(sorted, ["Zebra", "Beta", "alpha"])
    }

    func test_author_sortsAlphabeticallyThenTitle() {
        let books = [
            candidate(title: "B", author: "Smith"),
            candidate(title: "A", author: "Adams"),
            candidate(title: "C", author: "Smith"),
        ]

        let sorted = LibrarySorter.sorted(books, by: .author, direction: .ascending).map(\.title)
        XCTAssertEqual(sorted, ["A", "B", "C"])
    }

    func test_fileSize_sortsLargestFirst() {
        let books = [
            candidate(title: "Small", fileSize: 100),
            candidate(title: "Large", fileSize: 900),
            candidate(title: "Mid", fileSize: 500),
        ]

        let sorted = LibrarySorter.sorted(books, by: .fileSize).map(\.title)
        XCTAssertEqual(sorted, ["Large", "Mid", "Small"])
    }

    func test_duration_sortsLongestFirst() {
        let books = [
            candidate(title: "Short", duration: 100),
            candidate(title: "Long", duration: 9_000),
            candidate(title: "Mid", duration: 500),
        ]

        let sorted = LibrarySorter.sorted(books, by: .duration).map(\.title)
        XCTAssertEqual(sorted, ["Long", "Mid", "Short"])
    }

    func test_ascendingDirectionReversesDateAddedOrder() {
        let books = [
            candidate(title: "A", addedAt: day1),
            candidate(title: "B", addedAt: day3),
            candidate(title: "C", addedAt: day2),
        ]

        let sorted = LibrarySorter.sorted(books, by: .dateAdded, direction: .ascending).map(\.title)
        XCTAssertEqual(sorted, ["A", "C", "B"])
    }

    func test_libraryBookFilter_openedAndUnopened() {
        let opened = LibraryBookFilter.opened.includes(lastPlayedAt: day1)
        let unopened = LibraryBookFilter.unopened.includes(lastPlayedAt: nil)
        let all = LibraryBookFilter.all.includes(lastPlayedAt: nil)

        XCTAssertTrue(opened)
        XCTAssertFalse(LibraryBookFilter.opened.includes(lastPlayedAt: nil))
        XCTAssertTrue(unopened)
        XCTAssertFalse(LibraryBookFilter.unopened.includes(lastPlayedAt: day1))
        XCTAssertTrue(all)
    }

    private func candidate(
        title: String,
        author: String = "Author",
        duration: TimeInterval = 3_600,
        lastPlayedAt: Date? = nil,
        addedAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        fileSize: Int64 = 1_000
    ) -> LibrarySortCandidate {
        LibrarySortCandidate(
            id: UUID(),
            title: title,
            author: author,
            duration: duration,
            lastPlayedAt: lastPlayedAt,
            addedAt: addedAt,
            fileSize: fileSize
        )
    }
}

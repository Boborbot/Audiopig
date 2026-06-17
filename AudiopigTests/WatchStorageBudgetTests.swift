//
//  WatchStorageBudgetTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WatchStorageBudgetTests: XCTestCase {

    private let bookA = UUID()
    private let bookB = UUID()
    private let bookC = UUID()

    func test_canFit_whenUnderBudget() {
        let entries = [
            WatchStorageEntry(bookID: bookA, byteCount: 100, lastPlayedAt: nil, transferredAt: .now)
        ]
        XCTAssertTrue(WatchStorageBudget.canFit(entries: entries, incomingBytes: 50, budget: 200))
    }

    func test_canFit_whenOverBudget() {
        let entries = [
            WatchStorageEntry(bookID: bookA, byteCount: 150, lastPlayedAt: nil, transferredAt: .now)
        ]
        XCTAssertFalse(WatchStorageBudget.canFit(entries: entries, incomingBytes: 100, budget: 200))
    }

    func test_booksToEvict_evictsLeastRecentlyUsedFirst() {
        let old = Date(timeIntervalSince1970: 100)
        let mid = Date(timeIntervalSince1970: 200)
        let recent = Date(timeIntervalSince1970: 300)

        let entries = [
            WatchStorageEntry(bookID: bookA, byteCount: 80, lastPlayedAt: recent, transferredAt: mid),
            WatchStorageEntry(bookID: bookB, byteCount: 80, lastPlayedAt: nil, transferredAt: old),
            WatchStorageEntry(bookID: bookC, byteCount: 80, lastPlayedAt: mid, transferredAt: old)
        ]

        let evictions = WatchStorageBudget.booksToEvict(
            entries: entries,
            incomingBytes: 100,
            budget: 200
        )

        XCTAssertEqual(evictions, [bookB, bookC])
    }
}

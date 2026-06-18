//
//  WesterosFinishConditionTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WesterosFinishConditionTests: XCTestCase {

    private let totalSeconds: TimeInterval = 10_000
    private var listenedEnough: TimeInterval { totalSeconds * 0.80 }
    private var listenedTooLittle: TimeInterval { totalSeconds * 0.50 }

    // MARK: - Listening threshold

    func testUnlocksWhenListenedAtLeastSeventyFivePercent() {
        XCTAssertTrue(
            WesterosFinishCondition.isSatisfied(
                title: "A Game of Thrones",
                author: "Unknown Author",
                listenedSeconds: totalSeconds * 0.75,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockBelowSeventyFivePercent() {
        XCTAssertFalse(
            WesterosFinishCondition.isSatisfied(
                title: "A Storm of Swords",
                author: "George R.R. Martin",
                listenedSeconds: listenedTooLittle,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Author signals

    func testAuthorAloneDoesNotUnlock() {
        XCTAssertFalse(
            WesterosFinishCondition.isSatisfied(
                title: "Some Novella",
                author: "George R.R. Martin",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testGRRMAbbreviationAloneDoesNotUnlock() {
        XCTAssertFalse(
            WesterosFinishCondition.isSatisfied(
                title: "Short Fiction",
                author: "GRRM",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testInvertedAuthorAloneDoesNotUnlock() {
        XCTAssertFalse(
            WesterosFinishCondition.isSatisfied(
                title: "Volume 1",
                author: "Martin, George R.R.",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testMartinAloneDoesNotUnlock() {
        XCTAssertFalse(
            WesterosFinishCondition.isSatisfied(
                title: "Short Stories",
                author: "Martin",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Main five books

    func testUnlocksForAllFiveMainNovels() {
        let titles = [
            "A Game of Thrones",
            "A Clash of Kings",
            "A Storm of Swords",
            "A Feast for Crows",
            "A Dance with Dragons",
        ]
        for title in titles {
            XCTAssertTrue(
                WesterosFinishCondition.isSatisfied(
                    title: title,
                    author: "Unknown Author",
                    listenedSeconds: listenedEnough,
                    totalSeconds: totalSeconds
                ),
                "Expected unlock for \(title)"
            )
        }
    }

    func testUnlocksForSeriesTitle() {
        XCTAssertTrue(
            WesterosFinishCondition.isSatisfied(
                title: "A Song of Ice and Fire",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testUnlocksForASOIAFAbbreviation() {
        XCTAssertTrue(
            WesterosFinishCondition.isSatisfied(
                title: "ASOIAF Book 3",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Weak title signals

    func testWeakTitleAloneDoesNotUnlock() {
        XCTAssertFalse(
            WesterosFinishCondition.isSatisfied(
                title: "Thrones",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testWeakTitleWithAuthorUnlocks() {
        XCTAssertTrue(
            WesterosFinishCondition.isSatisfied(
                title: "Westeros Lore",
                author: "George RR Martin",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Negative cases

    func testUnrelatedBookDoesNotUnlock() {
        XCTAssertFalse(
            WesterosFinishCondition.isSatisfied(
                title: "The Name of the Wind",
                author: "Patrick Rothfuss",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testZeroDurationDoesNotUnlock() {
        XCTAssertFalse(
            WesterosFinishCondition.isSatisfied(
                title: "A Game of Thrones",
                author: "George R.R. Martin",
                listenedSeconds: 0,
                totalSeconds: 0
            )
        )
    }
}

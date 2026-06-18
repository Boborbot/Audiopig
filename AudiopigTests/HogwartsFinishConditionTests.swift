//
//  HogwartsFinishConditionTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class HogwartsFinishConditionTests: XCTestCase {

    private let totalSeconds: TimeInterval = 10_000
    private var listenedEnough: TimeInterval { totalSeconds * 0.80 }
    private var listenedTooLittle: TimeInterval { totalSeconds * 0.50 }

    // MARK: - Listening threshold

    func testUnlocksWhenListenedAtLeastSeventyFivePercent() {
        XCTAssertTrue(
            HogwartsFinishCondition.isSatisfied(
                title: "Harry Potter and the Deathly Hallows",
                author: "Unknown Author",
                listenedSeconds: totalSeconds * 0.75,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockBelowSeventyFivePercent() {
        XCTAssertFalse(
            HogwartsFinishCondition.isSatisfied(
                title: "Harry Potter and the Goblet of Fire",
                author: "J.K. Rowling",
                listenedSeconds: listenedTooLittle,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Author signals

    func testAuthorAloneDoesNotUnlock() {
        XCTAssertFalse(
            HogwartsFinishCondition.isSatisfied(
                title: "The Casual Vacancy",
                author: "J.K. Rowling",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Main seven novels

    func testUnlocksForAllSevenMainNovels() {
        let titles = [
            "Harry Potter and the Philosopher's Stone",
            "Harry Potter and the Sorcerer's Stone",
            "Harry Potter and the Chamber of Secrets",
            "Harry Potter and the Prisoner of Azkaban",
            "Harry Potter and the Goblet of Fire",
            "Harry Potter and the Order of the Phoenix",
            "Harry Potter and the Half-Blood Prince",
            "Harry Potter and the Deathly Hallows",
        ]
        for title in titles {
            XCTAssertTrue(
                HogwartsFinishCondition.isSatisfied(
                    title: title,
                    author: "Unknown Author",
                    listenedSeconds: listenedEnough,
                    totalSeconds: totalSeconds
                ),
                "Expected unlock for \(title)"
            )
        }
    }

    func testUnlocksForSubtitleOnlyTitle() {
        XCTAssertTrue(
            HogwartsFinishCondition.isSatisfied(
                title: "Prisoner of Azkaban (Unabridged)",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Weak title signals

    func testWeakTitleAloneDoesNotUnlock() {
        XCTAssertFalse(
            HogwartsFinishCondition.isSatisfied(
                title: "Azkaban",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testWeakTitleWithAuthorUnlocks() {
        XCTAssertTrue(
            HogwartsFinishCondition.isSatisfied(
                title: "Tales of Hogwarts",
                author: "J.K. Rowling",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Negative cases

    func testGenericHarryPotterTitleDoesNotUnlock() {
        XCTAssertFalse(
            HogwartsFinishCondition.isSatisfied(
                title: "Harry Potter",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testFantasticBeastsDoesNotUnlock() {
        XCTAssertFalse(
            HogwartsFinishCondition.isSatisfied(
                title: "Fantastic Beasts and Where to Find Them",
                author: "J.K. Rowling",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testCursedChildDoesNotUnlock() {
        XCTAssertFalse(
            HogwartsFinishCondition.isSatisfied(
                title: "Harry Potter and the Cursed Child",
                author: "J.K. Rowling",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testUnrelatedBookDoesNotUnlock() {
        XCTAssertFalse(
            HogwartsFinishCondition.isSatisfied(
                title: "The Hobbit",
                author: "J.R.R. Tolkien",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testZeroDurationDoesNotUnlock() {
        XCTAssertFalse(
            HogwartsFinishCondition.isSatisfied(
                title: "Harry Potter and the Chamber of Secrets",
                author: "J.K. Rowling",
                listenedSeconds: 0,
                totalSeconds: 0
            )
        )
    }
}

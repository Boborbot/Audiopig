//
//  MiddleEarthFinishConditionTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class MiddleEarthFinishConditionTests: XCTestCase {

    private let totalSeconds: TimeInterval = 10_000
    private var listenedEnough: TimeInterval { totalSeconds * 0.80 }
    private var listenedTooLittle: TimeInterval { totalSeconds * 0.50 }

    // MARK: - Listening threshold

    func testUnlocksWhenListenedAtLeastSeventyFivePercent() {
        XCTAssertTrue(
            MiddleEarthFinishCondition.isSatisfied(
                title: "The Hobbit",
                author: "Unknown Author",
                listenedSeconds: totalSeconds * 0.75,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockBelowSeventyFivePercent() {
        XCTAssertFalse(
            MiddleEarthFinishCondition.isSatisfied(
                title: "The Hobbit",
                author: "J.R.R. Tolkien",
                listenedSeconds: listenedTooLittle,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Author signals

    func testAuthorAloneDoesNotUnlock() {
        XCTAssertFalse(
            MiddleEarthFinishCondition.isSatisfied(
                title: "Some Random Title",
                author: "J.R.R. Tolkien",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testAuthorTypoAloneDoesNotUnlock() {
        XCTAssertFalse(
            MiddleEarthFinishCondition.isSatisfied(
                title: "Biography",
                author: "J.R.R. Tolkein",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testInvertedAuthorAloneDoesNotUnlock() {
        XCTAssertFalse(
            MiddleEarthFinishCondition.isSatisfied(
                title: "Volume 1",
                author: "Tolkien, J.R.R.",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Strong title signals

    func testUnlocksForLordOfTheRingsTitle() {
        XCTAssertTrue(
            MiddleEarthFinishCondition.isSatisfied(
                title: "The Lord of the Rings (Unabridged)",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testUnlocksForLOTRAbbreviation() {
        XCTAssertTrue(
            MiddleEarthFinishCondition.isSatisfied(
                title: "LOTR: The Two Towers",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testUnlocksForSilmarilionTypo() {
        XCTAssertTrue(
            MiddleEarthFinishCondition.isSatisfied(
                title: "The Silmarilion",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Weak title signals

    func testWeakTitleAloneDoesNotUnlock() {
        XCTAssertFalse(
            MiddleEarthFinishCondition.isSatisfied(
                title: "Hobbit",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testWeakTitleWithAuthorUnlocks() {
        XCTAssertTrue(
            MiddleEarthFinishCondition.isSatisfied(
                title: "Hobbit",
                author: "JRR Tolkien",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Negative cases

    func testUnrelatedBookDoesNotUnlock() {
        XCTAssertFalse(
            MiddleEarthFinishCondition.isSatisfied(
                title: "Pride and Prejudice",
                author: "Jane Austen",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testZeroDurationDoesNotUnlock() {
        XCTAssertFalse(
            MiddleEarthFinishCondition.isSatisfied(
                title: "The Hobbit",
                author: "J.R.R. Tolkien",
                listenedSeconds: 0,
                totalSeconds: 0
            )
        )
    }

    // MARK: - Normalization

    func testNormalizeCollapsesPunctuation() {
        XCTAssertEqual(
            MiddleEarthFinishCondition.normalize("J.R.R. Tolkien"),
            "j r r tolkien"
        )
    }
}

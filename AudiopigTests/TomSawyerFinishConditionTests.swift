//
//  TomSawyerFinishConditionTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class TomSawyerFinishConditionTests: XCTestCase {

    private let totalSeconds: TimeInterval = 10_000
    private var listenedEnough: TimeInterval { totalSeconds * 0.80 }
    private var listenedTooLittle: TimeInterval { totalSeconds * 0.50 }

    func testUnlocksWhenListenedAtLeastSeventyFivePercent() {
        XCTAssertTrue(
            TomSawyerFinishCondition.isSatisfied(
                title: "The Adventures of Tom Sawyer",
                author: "Mark Twain",
                listenedSeconds: totalSeconds * 0.75,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockBelowSeventyFivePercent() {
        XCTAssertFalse(
            TomSawyerFinishCondition.isSatisfied(
                title: "The Adventures of Tom Sawyer",
                author: "Mark Twain",
                listenedSeconds: listenedTooLittle,
                totalSeconds: totalSeconds
            )
        )
    }

    func testUnlocksForTomSawyerAndMarkTwain() {
        XCTAssertTrue(
            TomSawyerFinishCondition.isSatisfied(
                title: "Tom Sawyer",
                author: "Mark Twain",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testUnlocksForTypoVariants() {
        XCTAssertTrue(
            TomSawyerFinishCondition.isSatisfied(
                title: "The Adventures of Tom Sawer",
                author: "Samuel Clemens",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockForTomSawyerTitleAlone() {
        XCTAssertFalse(
            TomSawyerFinishCondition.isSatisfied(
                title: "The Adventures of Tom Sawyer",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockForMarkTwainAuthorAlone() {
        XCTAssertFalse(
            TomSawyerFinishCondition.isSatisfied(
                title: "Adventures of Huckleberry Finn",
                author: "Mark Twain",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockForUnrelatedBook() {
        XCTAssertFalse(
            TomSawyerFinishCondition.isSatisfied(
                title: "Moby-Dick",
                author: "Herman Melville",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testNormalizeFoldsPunctuationAndWhitespace() {
        XCTAssertEqual(
            TomSawyerFinishCondition.normalize("  Tom   Sawyer —  "),
            "tom sawyer"
        )
    }
}

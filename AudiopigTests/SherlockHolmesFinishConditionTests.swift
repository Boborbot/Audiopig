//
//  SherlockHolmesFinishConditionTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SherlockHolmesFinishConditionTests: XCTestCase {

    private let totalSeconds: TimeInterval = 10_000
    private var listenedEnough: TimeInterval { totalSeconds * 0.80 }
    private var listenedTooLittle: TimeInterval { totalSeconds * 0.50 }

    // MARK: - Listening threshold

    func testUnlocksWhenListenedAtLeastSeventyFivePercent() {
        XCTAssertTrue(
            SherlockHolmesFinishCondition.isSatisfied(
                title: "The Adventures of Sherlock Holmes",
                author: "Unknown Author",
                listenedSeconds: totalSeconds * 0.75,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockBelowSeventyFivePercent() {
        XCTAssertFalse(
            SherlockHolmesFinishCondition.isSatisfied(
                title: "Sherlock Holmes: A Study in Scarlet",
                author: "Arthur Conan Doyle",
                listenedSeconds: listenedTooLittle,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Title signals

    func testUnlocksWhenTitleContainsSherlockHolmes() {
        XCTAssertTrue(
            SherlockHolmesFinishCondition.isSatisfied(
                title: "Sherlock Holmes: The Complete Collection",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testUnlocksForCommonSherlockHolmesMisspellings() {
        let titles = [
            "Sherlock Holms: A Study in Scarlet",
            "Sherlock Homes and the Hound",
        ]
        for title in titles {
            XCTAssertTrue(
                SherlockHolmesFinishCondition.isSatisfied(
                    title: title,
                    author: "Unknown Author",
                    listenedSeconds: listenedEnough,
                    totalSeconds: totalSeconds
                ),
                "Expected unlock for \(title)"
            )
        }
    }

    func testDoesNotUnlockForSubtitleOnlyTitle() {
        XCTAssertFalse(
            SherlockHolmesFinishCondition.isSatisfied(
                title: "A Study in Scarlet",
                author: "Unknown Author",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testDoesNotUnlockForOtherHolmesBookTitles() {
        let titles = [
            "The Hound of the Baskervilles",
            "The Sign of the Four",
            "His Last Bow",
        ]
        for title in titles {
            XCTAssertFalse(
                SherlockHolmesFinishCondition.isSatisfied(
                    title: title,
                    author: "Unknown Author",
                    listenedSeconds: listenedEnough,
                    totalSeconds: totalSeconds
                ),
                "Expected no unlock for \(title)"
            )
        }
    }

    // MARK: - Author signals

    func testUnlocksForArthurConanDoyleAuthor() {
        XCTAssertTrue(
            SherlockHolmesFinishCondition.isSatisfied(
                title: "A Study in Scarlet",
                author: "Arthur Conan Doyle",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    func testUnlocksForAuthorTypoVariants() {
        let authors = [
            "Artur Conan Doyle",
            "Sir Arthur Conan Doyle",
            "Conan Doyle, Arthur",
        ]
        for author in authors {
            XCTAssertTrue(
                SherlockHolmesFinishCondition.isSatisfied(
                    title: "A Study in Scarlet",
                    author: author,
                    listenedSeconds: listenedEnough,
                    totalSeconds: totalSeconds
                ),
                "Expected unlock for author \(author)"
            )
        }
    }

    func testDoesNotUnlockForUnrelatedAuthor() {
        XCTAssertFalse(
            SherlockHolmesFinishCondition.isSatisfied(
                title: "A Study in Scarlet",
                author: "Agatha Christie",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }

    // MARK: - Normalization

    func testNormalizeFoldsPunctuationAndWhitespace() {
        XCTAssertEqual(
            SherlockHolmesFinishCondition.normalize("  Sherlock   Holmes:  A Study!  "),
            "sherlock holmes a study"
        )
    }

    func testDoesNotUnlockForUnrelatedBook() {
        XCTAssertFalse(
            SherlockHolmesFinishCondition.isSatisfied(
                title: "Murder on the Orient Express",
                author: "Agatha Christie",
                listenedSeconds: listenedEnough,
                totalSeconds: totalSeconds
            )
        )
    }
}

//
//  SecretAchievementConditionTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SecretAchievementConditionTests: XCTestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(month: Int, day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2025, month: month, day: day, hour: hour))!
    }

    private func finishEvent(at date: Date) -> BookFinishEvent {
        BookFinishEvent(
            audiobookID: UUID(),
            title: "Test",
            author: "Author",
            totalSeconds: 3600,
            listenedSeconds: 3600,
            chapterCount: 1,
            finishedAt: date,
            wasManuallyMarked: false
        )
    }

    func testChristmasDayUnlocksOnDecember25() {
        let event = finishEvent(at: date(month: 12, day: 25))
        XCTAssertTrue(SecretAchievement.christmasDay.isUnlocked(by: event, calendar: calendar))
        XCTAssertTrue(ChristmasDayFinishCondition.isChristmasDay(date(month: 12, day: 25), calendar: calendar))
    }

    func testChristmasDayDoesNotUnlockOnOtherDates() {
        let event = finishEvent(at: date(month: 12, day: 24))
        XCTAssertFalse(SecretAchievement.christmasDay.isUnlocked(by: event, calendar: calendar))
        XCTAssertFalse(ChristmasDayFinishCondition.isChristmasDay(date(month: 1, day: 1), calendar: calendar))
    }

    func testNewYearsEveUnlocksLateDecember31() {
        let event = finishEvent(at: date(month: 12, day: 31, hour: 22))
        XCTAssertTrue(SecretAchievement.newYearsEve.isUnlocked(by: event, calendar: calendar))
    }

    func testNewYearsEveUnlocksEarlyJanuary1() {
        let event = finishEvent(at: date(month: 1, day: 1, hour: 3))
        XCTAssertTrue(NewYearsEveFinishCondition.isWithinWindow(date(month: 1, day: 1, hour: 3), calendar: calendar))
    }

    func testNewYearsEveDoesNotUnlockOutsideWindow() {
        let afternoon = finishEvent(at: date(month: 12, day: 31, hour: 15))
        XCTAssertFalse(SecretAchievement.newYearsEve.isUnlocked(by: afternoon, calendar: calendar))
    }

    func testPigaladrielUnlocksForTolkienFinishWithEnoughListening() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "The Fellowship of the Ring",
            author: "J.R.R. Tolkien",
            totalSeconds: 10_000,
            listenedSeconds: 8_000,
            chapterCount: 24,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertTrue(SecretAchievement.pigaladriel.isUnlocked(by: event, calendar: calendar))
    }

    func testPigaladrielDoesNotUnlockForUnrelatedBook() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "Dune",
            author: "Frank Herbert",
            totalSeconds: 10_000,
            listenedSeconds: 9_000,
            chapterCount: 40,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertFalse(SecretAchievement.pigaladriel.isUnlocked(by: event, calendar: calendar))
    }

    func testSirPigNosalotUnlocksForASOIAFFinishWithEnoughListening() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "A Storm of Swords",
            author: "George R.R. Martin",
            totalSeconds: 10_000,
            listenedSeconds: 8_000,
            chapterCount: 82,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertTrue(SecretAchievement.sirPigNosalot.isUnlocked(by: event, calendar: calendar))
    }

    func testSirPigNosalotDoesNotUnlockForUnrelatedBook() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "The Way of Kings",
            author: "Brandon Sanderson",
            totalSeconds: 10_000,
            listenedSeconds: 9_000,
            chapterCount: 75,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertFalse(SecretAchievement.sirPigNosalot.isUnlocked(by: event, calendar: calendar))
    }

    func testThePigWhoLivedUnlocksForHarryPotterFinishWithEnoughListening() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "Harry Potter and the Prisoner of Azkaban",
            author: "J.K. Rowling",
            totalSeconds: 10_000,
            listenedSeconds: 8_000,
            chapterCount: 22,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertTrue(SecretAchievement.thePigWhoLived.isUnlocked(by: event, calendar: calendar))
    }

    func testThePigWhoLivedDoesNotUnlockForFantasticBeasts() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "Fantastic Beasts and Where to Find Them",
            author: "J.K. Rowling",
            totalSeconds: 10_000,
            listenedSeconds: 9_000,
            chapterCount: 12,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertFalse(SecretAchievement.thePigWhoLived.isUnlocked(by: event, calendar: calendar))
    }

    func testSherpigUnlocksForSherlockHolmesTitle() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "The Adventures of Sherlock Holmes",
            author: "Unknown Author",
            totalSeconds: 10_000,
            listenedSeconds: 8_000,
            chapterCount: 12,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertTrue(SecretAchievement.sherpig.isUnlocked(by: event, calendar: calendar))
    }

    func testSherpigUnlocksForConanDoyleAuthor() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "A Study in Scarlet",
            author: "Arthur Conan Doyle",
            totalSeconds: 10_000,
            listenedSeconds: 8_000,
            chapterCount: 14,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertTrue(SecretAchievement.sherpig.isUnlocked(by: event, calendar: calendar))
    }

    func testSherpigDoesNotUnlockForUnrelatedBook() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "Murder on the Orient Express",
            author: "Agatha Christie",
            totalSeconds: 10_000,
            listenedSeconds: 9_000,
            chapterCount: 14,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertFalse(SecretAchievement.sherpig.isUnlocked(by: event, calendar: calendar))
    }

    func testPigSawyerUnlocksForTomSawyerAndMarkTwain() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "The Adventures of Tom Sawyer",
            author: "Mark Twain",
            totalSeconds: 10_000,
            listenedSeconds: 8_000,
            chapterCount: 35,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertTrue(SecretAchievement.pigSawyer.isUnlocked(by: event, calendar: calendar))
    }

    func testPigSawyerDoesNotUnlockForHuckleberryFinnAlone() {
        let event = BookFinishEvent(
            audiobookID: UUID(),
            title: "Adventures of Huckleberry Finn",
            author: "Mark Twain",
            totalSeconds: 10_000,
            listenedSeconds: 9_000,
            chapterCount: 43,
            finishedAt: date(month: 6, day: 17),
            wasManuallyMarked: false
        )
        XCTAssertFalse(SecretAchievement.pigSawyer.isUnlocked(by: event, calendar: calendar))
    }
}

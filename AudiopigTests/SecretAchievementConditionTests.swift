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
}

//
//  WidgetWeeklyListeningSnapshotTests.swift
//  AudiopigTests
//

import XCTest
@testable import AudiopigShared

final class WidgetWeeklyListeningSnapshotTests: XCTestCase {

    func test_formatWeeklyTotalHoursMinutes_zeroSeconds_returnsZeroMinutes() {
        XCTAssertEqual(WidgetWeeklyListeningSnapshot.formatWeeklyTotalHoursMinutes(0), "0m")
    }

    func test_formatWeeklyTotalHoursMinutes_withHoursAndMinutes_formatsCompactly() {
        XCTAssertEqual(
            WidgetWeeklyListeningSnapshot.formatWeeklyTotalHoursMinutes(9_000),
            "2h30m"
        )
    }

    func test_formatWeeklyTotalHoursMinutes_subHourRoundsUpToOneMinute() {
        XCTAssertEqual(
            WidgetWeeklyListeningSnapshot.formatWeeklyTotalHoursMinutes(30),
            "1m"
        )
    }

    func test_weekdayLetter_validDayKey_returnsFirstLetter() {
        XCTAssertEqual(
            WidgetWeeklyListeningSnapshot.weekdayLetter(for: "2026-06-17"),
            "W"
        )
    }

    func test_weekdayLetter_invalidDayKey_returnsEmptyString() {
        XCTAssertEqual(
            WidgetWeeklyListeningSnapshot.weekdayLetter(for: "day-0"),
            ""
        )
    }
}

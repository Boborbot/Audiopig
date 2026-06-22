//
//  WidgetListeningSnapshotTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WidgetListeningSnapshotTests: XCTestCase {

    func test_playbackProgress_clampsToUnitInterval() {
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 0, duration: 100), 0)
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 50, duration: 100), 0.5, accuracy: 0.0001)
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 100, duration: 100), 1)
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 150, duration: 100), 1)
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 10, duration: 0), 0)
    }

    func test_formatTodayListeningHoursMinutes_omitsNeedlessZeros() {
        XCTAssertEqual(WidgetListeningSnapshot.formatTodayListeningHoursMinutes(0), "0m")
        XCTAssertEqual(WidgetListeningSnapshot.formatTodayListeningHoursMinutes(600), "10m")
        XCTAssertEqual(WidgetListeningSnapshot.formatTodayListeningHoursMinutes(3_600), "1h")
        XCTAssertEqual(WidgetListeningSnapshot.formatTodayListeningHoursMinutes(5_400), "1h30m")
        XCTAssertEqual(WidgetListeningSnapshot.formatTodayListeningHoursMinutes(30), "1m")
    }
}

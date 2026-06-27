//
//  SubtitleWindowPlannerTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SubtitleWindowPlannerTests: XCTestCase {

    func testInitialNearPlayheadWindowCentersOnPlayhead() {
        let window = SubtitleWindowPlanner.initialNearPlayheadWindow(
            playhead: 3600,
            bookDuration: 10_000
        )
        XCTAssertEqual(window.globalStart, 3600 - SubtitleWindowPlanner.playheadLeadIn, accuracy: 0.001)
        XCTAssertEqual(window.globalEnd, window.globalStart + SubtitleWindowPlanner.defaultWindowDuration, accuracy: 0.001)
    }

    func testWholeBookWindowsCoverDuration() {
        let windows = SubtitleWindowPlanner.wholeBookWindows(bookDuration: 25 * 60)
        XCTAssertEqual(windows.count, 3)
        XCTAssertEqual(windows.first?.globalStart, 0)
        XCTAssertEqual(windows.last?.globalEnd, 25 * 60)
    }
}

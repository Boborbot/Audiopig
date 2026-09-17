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

    func testWindowsFromCurrentSectionStartsAtContainingWindow() {
        let windows = SubtitleWindowPlanner.windowsFromCurrentSection(
            playhead: 25 * 60,
            bookDuration: 50 * 60
        )
        XCTAssertEqual(windows.map(\.globalStart), [20 * 60, 30 * 60, 40 * 60])
    }

    func testWindowsFromCurrentSectionAtBoundaryStartsAtNextSection() {
        let windows = SubtitleWindowPlanner.windowsFromCurrentSection(
            playhead: 20 * 60,
            bookDuration: 40 * 60
        )
        XCTAssertEqual(windows.map(\.globalStart), [20 * 60, 30 * 60])
    }

    func testWindowsFromCurrentSectionAtStartMatchesWholeBook() {
        let whole = SubtitleWindowPlanner.wholeBookWindows(bookDuration: 25 * 60)
        let fromStart = SubtitleWindowPlanner.windowsFromCurrentSection(
            playhead: 0,
            bookDuration: 25 * 60
        )
        XCTAssertEqual(fromStart, whole)
    }

    func testWindowsFromCurrentSectionAtEndIsEmpty() {
        let windows = SubtitleWindowPlanner.windowsFromCurrentSection(
            playhead: 40 * 60,
            bookDuration: 40 * 60
        )
        XCTAssertTrue(windows.isEmpty)
    }
}

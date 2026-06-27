//
//  SubtitleCueResolverTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SubtitleCueResolverTests: XCTestCase {

    private let cues: [SubtitleCueTiming] = [
        SubtitleCueTiming(startTime: 0, endTime: 2, text: "Line one", orderIndex: 0),
        SubtitleCueTiming(startTime: 2, endTime: 5, text: "Line two", orderIndex: 1),
        SubtitleCueTiming(startTime: 5, endTime: 8, text: "Line three", orderIndex: 2),
    ]

    func testResolveActiveCueIndexMidCue() {
        XCTAssertEqual(SubtitleCueResolver.resolveActiveCueIndex(at: 3, cues: cues), 1)
    }

    func testResolveActiveCueIndexReturnsNilBetweenCues() {
        XCTAssertNil(SubtitleCueResolver.resolveActiveCueIndex(at: 8, cues: cues))
        XCTAssertFalse(SubtitleCueResolver.hasActiveCue(at: 8, cues: cues))
    }

    func testHasActiveCueTrueInsideCue() {
        XCTAssertTrue(SubtitleCueResolver.hasActiveCue(at: 3, cues: cues))
    }

    func testVisibleWindowIncludesNeighbors() {
        let window = SubtitleCueResolver.visibleWindow(at: 3, cues: cues, radius: 1)
        XCTAssertEqual(window.cues.count, 3)
        XCTAssertEqual(window.activeIndex, 1)
    }

    func testVisibleWindowReturnsEmptyInGap() {
        let window = SubtitleCueResolver.visibleWindow(at: 8.5, cues: cues, radius: 1)
        XCTAssertTrue(window.cues.isEmpty)
        XCTAssertNil(window.activeIndex)
    }

    func testResolveActiveCueIndexWorksWhenOrderIndexDiffersFromTimeline() {
        let outOfOrder = [
            SubtitleCueTiming(startTime: 100, endTime: 102, text: "Later", orderIndex: 0),
            SubtitleCueTiming(startTime: 0, endTime: 2, text: "Earlier", orderIndex: 1),
            SubtitleCueTiming(startTime: 50, endTime: 52, text: "Middle", orderIndex: 2)
        ]
        let sorted = outOfOrder.sorted {
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.orderIndex < $1.orderIndex
        }
        XCTAssertEqual(SubtitleCueResolver.resolveActiveCueIndex(at: 1, cues: sorted), 0)
        XCTAssertEqual(SubtitleCueResolver.resolveActiveCueIndex(at: 51, cues: sorted), 2)
    }

    func testHasCoverageDetectsOverlap() {
        let window = SubtitleTimeWindow(globalStart: 1, globalEnd: 3)
        XCTAssertTrue(SubtitleCueResolver.hasCoverage(in: window, cues: cues))
    }

    func testHasCoverageReturnsFalseForGap() {
        let window = SubtitleTimeWindow(globalStart: 10, globalEnd: 12)
        XCTAssertFalse(SubtitleCueResolver.hasCoverage(in: window, cues: cues))
    }
}

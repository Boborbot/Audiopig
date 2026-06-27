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

    func testResolveDisplayCueIndexHoldsPreviousLineInGap() {
        XCTAssertEqual(SubtitleCueResolver.resolveDisplayCueIndex(at: 8.5, cues: cues), 2)
        XCTAssertNil(SubtitleCueResolver.resolveActiveCueIndex(at: 8.5, cues: cues))
    }

    func testResolveDisplayCueIndexReturnsNilBeforeFirstCue() {
        let laterCues = [
            SubtitleCueTiming(startTime: 10, endTime: 12, text: "Later", orderIndex: 0)
        ]
        XCTAssertNil(SubtitleCueResolver.resolveDisplayCueIndex(at: 5, cues: laterCues))
    }

    func testResolveDisplayCueIndexMatchesActiveCueWhileSpeaking() {
        XCTAssertEqual(SubtitleCueResolver.resolveDisplayCueIndex(at: 3, cues: cues), 1)
    }

    func testVisibleWindowIncludesNeighbors() {
        let window = SubtitleCueResolver.visibleWindow(at: 3, cues: cues, radius: 1)
        XCTAssertEqual(window.cues.count, 3)
        XCTAssertEqual(window.activeIndex, 1)
    }

    func testVisibleWindowHoldsPreviousLineInGap() {
        let gappedCues = [
            SubtitleCueTiming(startTime: 0, endTime: 2, text: "Line one", orderIndex: 0),
            SubtitleCueTiming(startTime: 5, endTime: 8, text: "Line two", orderIndex: 1),
        ]
        let window = SubtitleCueResolver.visibleWindow(at: 3, cues: gappedCues, radius: 1)
        XCTAssertEqual(window.cues.count, 1)
        XCTAssertEqual(window.activeIndex, 0)
        XCTAssertEqual(window.cues[0].text, "Line one")
    }

    func testVisibleWindowReturnsEmptyBeforeFirstCue() {
        let laterCues = [
            SubtitleCueTiming(startTime: 10, endTime: 12, text: "Later", orderIndex: 0)
        ]
        let window = SubtitleCueResolver.visibleWindow(at: 5, cues: laterCues, radius: 1)
        XCTAssertTrue(window.cues.isEmpty)
        XCTAssertNil(window.activeIndex)
    }

    func testVisibleWindowHoldsLastLineAfterFinalCue() {
        let window = SubtitleCueResolver.visibleWindow(at: 20, cues: cues, radius: 1)
        XCTAssertEqual(window.cues.count, 2)
        XCTAssertEqual(window.activeIndex, 1)
        XCTAssertEqual(window.cues[1].text, "Line three")
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
        XCTAssertEqual(SubtitleCueResolver.resolveActiveCueIndex(at: 51, cues: sorted), 1)
    }

    func testVisibleWindowDefaultRadiusIsSeventeen() {
        let cues = (0..<40).map { index in
            SubtitleCueTiming(
                startTime: TimeInterval(index * 2),
                endTime: TimeInterval(index * 2 + 1),
                text: "Line \(index)",
                orderIndex: index
            )
        }
        let window = SubtitleCueResolver.visibleWindow(at: 41, cues: cues)
        XCTAssertEqual(window.cues.count, 35)
        XCTAssertEqual(window.activeIndex, 17)
    }

    func testSlidingWindowTopRemovalCountsForwardSlide() {
        let old = ["a", "b", "c", "d", "e"]
        let new = ["b", "c", "d", "e", "f"]
        XCTAssertEqual(SubtitleCueResolver.slidingWindowTopRemoval(old: old, new: new), 1)
    }

    func testSlidingWindowTopInsertionCountsBackwardSlide() {
        let old = ["b", "c", "d", "e", "f"]
        let new = ["a", "b", "c", "d", "e"]
        XCTAssertEqual(SubtitleCueResolver.slidingWindowTopInsertion(old: old, new: new), 1)
    }

    func testSlidingWindowTopRemovalReturnsZeroWhenUnchanged() {
        let ids = ["a", "b", "c"]
        XCTAssertEqual(SubtitleCueResolver.slidingWindowTopRemoval(old: ids, new: ids), 0)
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

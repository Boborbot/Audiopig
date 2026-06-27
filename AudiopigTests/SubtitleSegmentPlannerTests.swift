//
//  SubtitleSegmentPlannerTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SubtitleSegmentPlannerTests: XCTestCase {

    func testFullyCoversRequiresNearlyCompleteWindow() {
        let window = SubtitleTimeWindow(globalStart: 0, globalEnd: 600)
        let segments = [SubtitleTranscriptionSegmentTiming(startTime: 0, endTime: 590)]
        XCTAssertTrue(SubtitleSegmentPlanner.fullyCovers(window: window, segments: segments))
    }

    func testSwissCheesePlayheadWindowQueuedWhenSegmentMissing() {
        let segments = [
            SubtitleTranscriptionSegmentTiming(startTime: 0, endTime: 600),
            SubtitleTranscriptionSegmentTiming(startTime: 1200, endTime: 1800)
        ]
        let playhead: TimeInterval = 15 * 60
        let window = SubtitleSegmentPlanner.nearPlayheadTranscriptionWindow(
            playhead: playhead,
            bookDuration: 3600,
            segments: segments
        )
        XCTAssertEqual(window?.globalStart, 13 * 60, accuracy: 0.001)
        XCTAssertEqual(window?.globalEnd, 23 * 60, accuracy: 0.001)
    }

    func testUncoveredWindowsFindsMiddleGap() {
        let segments = [
            SubtitleTranscriptionSegmentTiming(startTime: 0, endTime: 600),
            SubtitleTranscriptionSegmentTiming(startTime: 1200, endTime: 1800)
        ]
        let uncovered = SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: 30 * 60,
            segments: segments
        )
        XCTAssertEqual(uncovered.count, 1)
        XCTAssertEqual(uncovered.first?.globalStart, 600, accuracy: 0.001)
        XCTAssertEqual(uncovered.first?.globalEnd, 1200, accuracy: 0.001)
    }

    func testLegacyBackfillSkipsSparseWindow() {
        let cues = [SubtitleCueTiming(startTime: 590, endTime: 595, text: "Tail", orderIndex: 0)]
        let inferred = SubtitleSegmentPlanner.inferredSegmentsFromLegacyCues(
            cues: cues,
            bookDuration: 20 * 60
        )
        XCTAssertTrue(inferred.isEmpty)
    }

    func testLegacyBackfillMarksDenseWindow() {
        let cues = (0..<60).map {
            SubtitleCueTiming(
                startTime: TimeInterval($0 * 10),
                endTime: TimeInterval($0 * 10 + 8),
                text: "Line \($0)",
                orderIndex: $0
            )
        }
        let inferred = SubtitleSegmentPlanner.inferredSegmentsFromLegacyCues(
            cues: cues,
            bookDuration: 20 * 60
        )
        XCTAssertEqual(inferred.count, 1)
        XCTAssertEqual(inferred.first?.startTime, 0, accuracy: 0.001)
        XCTAssertEqual(inferred.first?.endTime, 600, accuracy: 0.001)
    }

    func testShouldAutoGenerateWhenApproachingForwardSegmentEdge() {
        let segments = [SubtitleTranscriptionSegmentTiming(startTime: 0, endTime: 600)]
        let cues = [SubtitleCueTiming(startTime: 0, endTime: 600, text: "A", orderIndex: 0)]
        let playhead = 600 - SubtitleWindowPlanner.playheadLeadIn + 10
        XCTAssertTrue(
            SubtitleSegmentPlanner.shouldAutoGenerateNearPlayhead(
                playhead: playhead,
                bookDuration: 3600,
                segments: segments,
                cues: cues
            )
        )
    }

    func testShouldNotAutoGenerateWhenActiveCueAtPlayhead() {
        let segments = [SubtitleTranscriptionSegmentTiming(startTime: 0, endTime: 600)]
        let cues = [SubtitleCueTiming(startTime: 0, endTime: 600, text: "A", orderIndex: 0)]
        XCTAssertFalse(
            SubtitleSegmentPlanner.shouldAutoGenerateNearPlayhead(
                playhead: 100,
                bookDuration: 3600,
                segments: segments,
                cues: cues
            )
        )
    }
}

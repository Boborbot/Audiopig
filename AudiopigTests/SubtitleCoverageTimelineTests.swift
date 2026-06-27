//
//  SubtitleCoverageTimelineTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SubtitleCoverageTimelineTests: XCTestCase {

    func testTimelineMapsMergedSegmentsToProportionalRuns() {
        let segments = [
            SubtitleTranscriptionSegmentTiming(startTime: 0, endTime: 300),
            SubtitleTranscriptionSegmentTiming(startTime: 302, endTime: 600),
            SubtitleTranscriptionSegmentTiming(startTime: 900, endTime: 1200),
        ]
        let timeline = SubtitleCoverageTimelineMapper.timeline(
            segments: segments,
            bookDuration: 20 * 60
        )

        XCTAssertEqual(timeline.runs.count, 2)
        XCTAssertEqual(timeline.runs[0].startTime, 0, accuracy: 0.01)
        XCTAssertEqual(timeline.runs[0].endTime, 600, accuracy: 0.01)
        XCTAssertEqual(timeline.runs[1].startTime, 900, accuracy: 0.01)
        XCTAssertEqual(timeline.runs[1].endTime, 1200, accuracy: 0.01)
        XCTAssertEqual(timeline.coverageFraction, 900.0 / (20 * 60), accuracy: 0.01)
        XCTAssertEqual(timeline.uncoveredWindowCount, 1)
    }

    func testTimelineClampsRunsToBookDuration() {
        let segments = [
            SubtitleTranscriptionSegmentTiming(startTime: 100, endTime: 25 * 60),
        ]
        let timeline = SubtitleCoverageTimelineMapper.timeline(
            segments: segments,
            bookDuration: 20 * 60
        )

        XCTAssertEqual(timeline.runs.count, 1)
        XCTAssertEqual(timeline.runs[0].startTime, 100, accuracy: 0.01)
        XCTAssertEqual(timeline.runs[0].endTime, 20 * 60, accuracy: 0.01)
    }

    func testTimelineEmptyWhenNoSegments() {
        let timeline = SubtitleCoverageTimelineMapper.timeline(
            segments: [],
            bookDuration: 60 * 60
        )

        XCTAssertTrue(timeline.runs.isEmpty)
        XCTAssertEqual(timeline.coverageFraction, 0)
        XCTAssertEqual(timeline.uncoveredWindowCount, 6)
    }
}

//
//  SubtitleCoverageCalculatorTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SubtitleCoverageCalculatorTests: XCTestCase {

    func testSummaryCountsSegmentCoveredWindows() {
        let cues = [
            SubtitleCueTiming(startTime: 30, endTime: 40, text: "Hello", orderIndex: 0),
        ]
        let segments = [
            SubtitleTranscriptionSegmentTiming(startTime: 0, endTime: 600)
        ]
        let summary = SubtitleCoverageCalculator.summary(
            cues: cues,
            segments: segments,
            bookDuration: 20 * 60,
            windowDuration: 10 * 60
        )
        XCTAssertEqual(summary.totalWindowCount, 2)
        XCTAssertEqual(summary.coveredWindowCount, 1)
        XCTAssertEqual(summary.uncoveredWindowCount, 1)
        XCTAssertEqual(summary.cueCount, 1)
        XCTAssertGreaterThan(summary.estimatedStorageBytes, 0)
        XCTAssertEqual(summary.transcribedDurationFraction, 0.5, accuracy: 0.01)
    }
}

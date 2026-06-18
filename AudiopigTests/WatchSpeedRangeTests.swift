//
//  WatchSpeedRangeTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WatchSpeedRangeTests: XCTestCase {

    func test_formatLabel_omitsTrailingZeros() {
        XCTAssertEqual(WatchSpeedRange.formatLabel(1.0), "1×")
        XCTAssertEqual(WatchSpeedRange.formatLabel(1.1), "1.1×")
        XCTAssertEqual(WatchSpeedRange.formatLabel(1.15), "1.15×")
        XCTAssertEqual(WatchSpeedRange.formatLabel(0.25), "0.25×")
        XCTAssertEqual(WatchSpeedRange.formatLabel(1.2), "1.2×")
        XCTAssertEqual(WatchSpeedRange.formatLabel(4.0), "4×")
    }

    func test_adjustedMovesByExactStepCount() {
        XCTAssertEqual(WatchSpeedRange.adjusted(1.0, byStepCount: 1), 1.05, accuracy: 0.0001)
        XCTAssertEqual(WatchSpeedRange.adjusted(1.05, byStepCount: 1), 1.1, accuracy: 0.0001)
        XCTAssertEqual(WatchSpeedRange.adjusted(1.1, byStepCount: 1), 1.15, accuracy: 0.0001)
        XCTAssertEqual(WatchSpeedRange.adjusted(1.15, byStepCount: -1), 1.1, accuracy: 0.0001)
    }

    func test_adjustedRepeatedIncrementsStayOnGrid() {
        var speed: Float = 1.0
        for _ in 0..<20 {
            speed = WatchSpeedRange.adjusted(speed, byStepCount: 1)
        }
        XCTAssertEqual(speed, 2.0, accuracy: 0.0001)
        XCTAssertEqual(WatchSpeedRange.formatLabel(speed), "2×")
    }

    func test_normalizedSnapsToFiveCentSteps() {
        XCTAssertEqual(WatchSpeedRange.normalized(1.07), 1.05, accuracy: 0.0001)
        XCTAssertEqual(WatchSpeedRange.normalized(1.08), 1.1, accuracy: 0.0001)
        XCTAssertEqual(WatchSpeedRange.normalized(0.2), 0.25, accuracy: 0.0001)
        XCTAssertEqual(WatchSpeedRange.normalized(4.1), 4.0, accuracy: 0.0001)
    }

    func test_normalizedPreservesExactSteps() {
        var stepIndex = 5
        while stepIndex <= 80 {
            let speed = Float(stepIndex * 5) / 100
            XCTAssertEqual(WatchSpeedRange.normalized(speed), speed, accuracy: 0.0001)
            stepIndex += 1
        }
    }
}

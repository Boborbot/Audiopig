//
//  WatchVolumeRangeTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WatchVolumeRangeTests: XCTestCase {

    func test_normalizedSnapsToSixteenthSteps() {
        XCTAssertEqual(WatchVolumeRange.normalized(0.04), 0.0625, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.normalized(0.49), 0.5, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.normalized(1.1), 1.0, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.normalized(-0.2), 0.0, accuracy: 0.0001)
    }

    func test_normalizedPreservesExactSteps() {
        for step in 0...16 {
            let value = Float(step) * WatchVolumeRange.step
            XCTAssertEqual(WatchVolumeRange.normalized(value), value, accuracy: 0.0001)
        }
    }

    func test_crownStepIsThreeTimesCoarserThanOriginalFineStep() {
        XCTAssertEqual(WatchVolumeRange.crownStep, WatchVolumeRange.step / 2, accuracy: 0.000001)
        XCTAssertEqual(WatchVolumeRange.crownStep, WatchVolumeRange.step / 6 * 3, accuracy: 0.000001)
    }

    func test_crownAxisInvertsVolume() {
        XCTAssertEqual(WatchVolumeRange.crownAxis(for: 0), 1, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.crownAxis(for: 1), 0, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.volume(fromCrownAxis: 1), 0, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.volume(fromCrownAxis: 0), 1, accuracy: 0.0001)
    }
}

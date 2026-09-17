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

    func test_crownStepIsOneThirdPreviousSensitivity() {
        XCTAssertEqual(WatchVolumeRange.crownStep, WatchVolumeRange.step / 6, accuracy: 0.000001)
        XCTAssertEqual(WatchVolumeRange.crownStep * 3, WatchVolumeRange.step / 2, accuracy: 0.000001)
    }

    func test_crownRangeIsAscendingAndMapsDirectlyToVolume() {
        XCTAssertLessThan(WatchVolumeRange.crownMinimum, WatchVolumeRange.crownMaximum)
        XCTAssertEqual(WatchVolumeRange.crownValue(for: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.crownValue(for: 1), 1, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.volume(fromCrownValue: 0), 0, accuracy: 0.0001)
        XCTAssertEqual(WatchVolumeRange.volume(fromCrownValue: 1), 1, accuracy: 0.0001)
    }
}

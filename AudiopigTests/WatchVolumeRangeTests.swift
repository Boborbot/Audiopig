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
}

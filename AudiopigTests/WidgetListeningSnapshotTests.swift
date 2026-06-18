//
//  WidgetListeningSnapshotTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WidgetListeningSnapshotTests: XCTestCase {

    func test_playbackProgress_clampsToUnitInterval() {
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 0, duration: 100), 0)
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 50, duration: 100), 0.5, accuracy: 0.0001)
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 100, duration: 100), 1)
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 150, duration: 100), 1)
        XCTAssertEqual(WidgetListeningSnapshot.playbackProgress(currentTime: 10, duration: 0), 0)
    }
}

//
//  SmartRewindWindowPolicyTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SmartRewindWindowPolicyTests: XCTestCase {

    func test_clampedOffsets_nearScope_enforcesMinimumGap() {
        let offsets = SmartRewindWindowPolicy.clampedOffsets(
            SmartRewindWindowOffsets(startOffset: 120, endOffset: 118),
            for: .near
        )
        XCTAssertEqual(offsets.startOffset, 120)
        XCTAssertEqual(offsets.endOffset, 115)
    }

    func test_clampedOffsets_farScope_enforcesMinimumGap() {
        let offsets = SmartRewindWindowPolicy.clampedOffsets(
            SmartRewindWindowOffsets(startOffset: 600, endOffset: 590),
            for: .far
        )
        XCTAssertEqual(offsets.startOffset, 600)
        XCTAssertEqual(offsets.endOffset, 570)
    }

    func test_playbackWindow_usesOffsetsBeforeCurrentTime() {
        let window = SmartRewindWindowPolicy.playbackWindow(
            currentTime: 900,
            offsets: SmartRewindWindowOffsets(startOffset: 300, endOffset: 30)
        )
        XCTAssertEqual(window.from, 600)
        XCTAssertEqual(window.to, 870)
    }

    func test_formatOffsetLabel_showsNowForNearEnd() {
        XCTAssertEqual(SmartRewindWindowPolicy.formatOffsetLabel(0, allowsNow: true), "Now")
        XCTAssertEqual(SmartRewindWindowPolicy.formatOffsetLabel(120), "2 min ago")
        XCTAssertEqual(SmartRewindWindowPolicy.formatOffsetLabel(45), "45s ago")
    }
}

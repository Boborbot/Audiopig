//
//  ChapterTimelineEditorTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class ChapterTimelineEditorTests: XCTestCase {

    func test_usesStackedTimeline_singleFile_returnsFalse() {
        let url = URL(fileURLWithPath: "/tmp/book.m4b")
        XCTAssertFalse(ChapterTimelineEditor.usesStackedTimeline(fileURLs: [url, url]))
    }

    func test_usesStackedTimeline_multipleFiles_returnsTrue() {
        let first = URL(fileURLWithPath: "/tmp/01.mp3")
        let second = URL(fileURLWithPath: "/tmp/02.mp3")
        XCTAssertTrue(ChapterTimelineEditor.usesStackedTimeline(fileURLs: [first, second]))
    }

    func test_stackedStartTimes_buildsCumulativeOffsets() {
        let starts = ChapterTimelineEditor.stackedStartTimes(durations: [100, 250, 50])
        XCTAssertEqual(starts, [0, 100, 350])
    }

    func test_totalDuration_sumsChapterLengths() {
        XCTAssertEqual(ChapterTimelineEditor.totalDuration(durations: [90, 10, 5]), 105)
    }

    func test_sanitizedTitle_emptyString_usesFallback() {
        XCTAssertEqual(ChapterTimelineEditor.sanitizedTitle("   ", fallback: "Chapter 2"), "Chapter 2")
    }

    func test_sanitizedTitle_nonEmpty_trimsWhitespace() {
        XCTAssertEqual(ChapterTimelineEditor.sanitizedTitle("  Intro  ", fallback: "Chapter 1"), "Intro")
    }
}

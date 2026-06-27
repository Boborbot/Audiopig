//
//  ChapterProgressCalculatorTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class ChapterProgressCalculatorTests: XCTestCase {

    private let chapters: [WatchChapterTiming] = [
        WatchChapterTiming(startTime: 0, duration: 100),
        WatchChapterTiming(startTime: 100, duration: 200),
        WatchChapterTiming(startTime: 300, duration: 150),
    ]

    func testEmptyChaptersReturnsZeroProgress() {
        let result = ChapterProgressCalculator.progress(globalTime: 50, chapters: [])
        XCTAssertEqual(result.chapterIndex, 0)
        XCTAssertEqual(result.chapterElapsed, 0)
        XCTAssertEqual(result.chapterDuration, 0)
        XCTAssertEqual(result.chapterProgress, 0)
    }

    func testProgressAtChapterStart() {
        let result = ChapterProgressCalculator.progress(globalTime: 100, chapters: chapters)
        XCTAssertEqual(result.chapterIndex, 1)
        XCTAssertEqual(result.chapterElapsed, 0, accuracy: 0.001)
        XCTAssertEqual(result.chapterDuration, 200, accuracy: 0.001)
        XCTAssertEqual(result.chapterProgress, 0, accuracy: 0.001)
    }

    func testProgressMidChapter() {
        let result = ChapterProgressCalculator.progress(globalTime: 150, chapters: chapters)
        XCTAssertEqual(result.chapterIndex, 1)
        XCTAssertEqual(result.chapterElapsed, 50, accuracy: 0.001)
        XCTAssertEqual(result.chapterProgress, 0.25, accuracy: 0.001)
    }

    func testResolveChapterIndexUsesBinarySearch() {
        XCTAssertEqual(ChapterProgressCalculator.resolveChapterIndex(for: 0, chapters: chapters), 0)
        XCTAssertEqual(ChapterProgressCalculator.resolveChapterIndex(for: 99.9, chapters: chapters), 0)
        XCTAssertEqual(ChapterProgressCalculator.resolveChapterIndex(for: 250, chapters: chapters), 1)
        XCTAssertEqual(ChapterProgressCalculator.resolveChapterIndex(for: 449, chapters: chapters), 2)
    }

    func testProgressPastEndClampsToLastChapter() {
        let result = ChapterProgressCalculator.progress(globalTime: 500, chapters: chapters)
        XCTAssertEqual(result.chapterIndex, 2)
        XCTAssertEqual(result.chapterDuration, 150, accuracy: 0.001)
    }

    func testChapterTitleReturnsNilForSingleChapterBook() {
        let single = [
            WatchChapterSummary(
                id: UUID(),
                title: "Whole Book",
                startTime: 0,
                duration: 100,
                orderIndex: 0
            )
        ]
        XCTAssertNil(ChapterProgressCalculator.chapterTitle(at: 10, chapters: single))
    }

    func testChapterTitleResolvesMultiChapterBook() {
        let multi = [
            WatchChapterSummary(id: UUID(), title: "Intro", startTime: 0, duration: 100, orderIndex: 0),
            WatchChapterSummary(id: UUID(), title: "Middle", startTime: 100, duration: 200, orderIndex: 1),
        ]
        XCTAssertEqual(ChapterProgressCalculator.chapterTitle(at: 150, chapters: multi), "Middle")
    }
}

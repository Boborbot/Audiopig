//
//  SubtitleLineGrouperTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SubtitleLineGrouperTests: XCTestCase {

    func testGroupIntoLinesMergesShortRuns() {
        let runs = [
            TimedTextRun(text: "Hello", startTime: 0, endTime: 0.4),
            TimedTextRun(text: "world", startTime: 0.45, endTime: 0.9),
        ]
        let lines = SubtitleLineGrouper.groupIntoLines(runs)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].text, "Hello world")
    }

    func testGroupIntoLinesSplitsOnLongPause() {
        let runs = [
            TimedTextRun(text: "First", startTime: 0, endTime: 0.5),
            TimedTextRun(text: "Second", startTime: 1.2, endTime: 1.8),
        ]
        let lines = SubtitleLineGrouper.groupIntoLines(runs)
        XCTAssertEqual(lines.count, 2)
    }

    func testGroupIntoLinesPrefersSentenceEndOverWordBoundary() {
        let runs = [
            TimedTextRun(text: "Hello", startTime: 0, endTime: 0.3),
            TimedTextRun(text: "world.", startTime: 0.35, endTime: 0.7),
            TimedTextRun(text: "Foo", startTime: 0.75, endTime: 1.0),
            TimedTextRun(text: "bar", startTime: 1.05, endTime: 1.3),
            TimedTextRun(text: "baz", startTime: 1.35, endTime: 1.6),
        ]
        let lines = SubtitleLineGrouper.groupIntoLines(runs, maxCharacters: 20)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "Hello world.")
        XCTAssertEqual(lines[1].text, "Foo bar baz")
        XCTAssertEqual(lines[0].startTime, 0)
        XCTAssertEqual(lines[0].endTime, 0.7)
        XCTAssertEqual(lines[1].startTime, 0.75)
        XCTAssertEqual(lines[1].endTime, 1.6)
    }

    func testGroupIntoLinesPrefersCommaWhenNoSentenceEnd() {
        let runs = [
            TimedTextRun(text: "The", startTime: 0, endTime: 0.2),
            TimedTextRun(text: "first", startTime: 0.25, endTime: 0.45),
            TimedTextRun(text: "part", startTime: 0.5, endTime: 0.7),
            TimedTextRun(text: "is", startTime: 0.75, endTime: 0.9),
            TimedTextRun(text: "long", startTime: 0.95, endTime: 1.15),
            TimedTextRun(text: "enough,", startTime: 1.2, endTime: 1.45),
            TimedTextRun(text: "and", startTime: 1.5, endTime: 1.65),
            TimedTextRun(text: "more", startTime: 1.7, endTime: 1.9),
            TimedTextRun(text: "words", startTime: 1.95, endTime: 2.2),
            TimedTextRun(text: "follow", startTime: 2.25, endTime: 2.5),
        ]
        let lines = SubtitleLineGrouper.groupIntoLines(runs, maxCharacters: 35)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "The first part is long enough,")
        XCTAssertEqual(lines[1].text, "and more words follow")
    }

    func testGroupIntoLinesFallsBackToWordBoundaryWithoutPunctuation() {
        let runs = [
            TimedTextRun(text: "one", startTime: 0, endTime: 0.2),
            TimedTextRun(text: "two", startTime: 0.25, endTime: 0.45),
            TimedTextRun(text: "three", startTime: 0.5, endTime: 0.7),
            TimedTextRun(text: "four", startTime: 0.75, endTime: 0.95),
        ]
        let lines = SubtitleLineGrouper.groupIntoLines(runs, maxCharacters: 10)
        XCTAssertEqual(lines.count, 2)
        XCTAssertEqual(lines[0].text, "one two")
        XCTAssertEqual(lines[1].text, "three four")
    }
}

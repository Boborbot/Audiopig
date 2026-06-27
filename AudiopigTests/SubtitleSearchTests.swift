//
//  SubtitleSearchTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SubtitleSearchTests: XCTestCase {

    private let cues: [SubtitleCueTiming] = [
        SubtitleCueTiming(startTime: 0, endTime: 2, text: "The quick brown fox", orderIndex: 0),
        SubtitleCueTiming(startTime: 2, endTime: 5, text: "jumps over the lazy dog", orderIndex: 1),
        SubtitleCueTiming(startTime: 5, endTime: 8, text: "and runs away", orderIndex: 2),
    ]

    func testEmptyQueryReturnsNoResults() {
        XCTAssertTrue(SubtitleSearch.matchingCues(query: "", in: cues).isEmpty)
        XCTAssertTrue(SubtitleSearch.matchingCues(query: "   ", in: cues).isEmpty)
    }

    func testMatchingCuesFindsSubstring() {
        let results = SubtitleSearch.matchingCues(query: "lazy", in: cues)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "jumps over the lazy dog")
    }

    func testMatchingCuesIsCaseInsensitive() {
        let results = SubtitleSearch.matchingCues(query: "FOX", in: cues)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].orderIndex, 0)
    }

    func testMatchingCuesRespectsLimit() {
        let results = SubtitleSearch.search(query: "the", in: cues, limit: 1)
        XCTAssertEqual(results.matches.count, 1)
        XCTAssertEqual(results.totalCount, 2)
    }

    func testMatchingCuesFindsPhraseSplitAcrossLines() {
        let results = SubtitleSearch.matchingCues(query: "fox jumps", in: cues)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].text, "The quick brown fox")
        XCTAssertEqual(results[0].orderIndex, 0)
    }

    func testMatchingCuesDoesNotDuplicateWhenFirstLineAlsoMatches() {
        let results = SubtitleSearch.matchingCues(query: "brown fox", in: cues)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].orderIndex, 0)
    }
}

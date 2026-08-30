//
//  CoverArtSearchTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class CoverArtSearchTests: XCTestCase {

    func testEmptyTitleReturnsNil() {
        XCTAssertNil(CoverArtSearch.googleImagesURL(title: ""))
        XCTAssertNil(CoverArtSearch.googleImagesURL(title: "   "))
    }

    func testBuildsGoogleImagesSearchURL() throws {
        let url = try XCTUnwrap(CoverArtSearch.googleImagesURL(title: "Dune"))
        XCTAssertEqual(url.host, "www.google.com")
        XCTAssertEqual(url.path, "/search")

        let items = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        XCTAssertEqual(items.first { $0.name == "tbm" }?.value, "isch")
        XCTAssertEqual(items.first { $0.name == "q" }?.value, "Dune audiobook")
    }

    func testTrimsWhitespaceFromTitle() throws {
        let url = try XCTUnwrap(CoverArtSearch.googleImagesURL(title: "  The Hobbit  "))
        let query = try XCTUnwrap(
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "q" }?
                .value
        )
        XCTAssertEqual(query, "The Hobbit audiobook")
    }
}

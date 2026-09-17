//
//  WatchPlayerPageLayoutTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WatchPlayerPageLayoutTests: XCTestCase {
    func test_pages_off_areSpeedMediaChapters() {
        XCTAssertEqual(
            WatchPlayerPageLayout.pages(artworkViewMode: .off),
            [.speed, .media, .chapters]
        )
    }

    func test_pages_replace_swapsMediaForArtwork() {
        XCTAssertEqual(
            WatchPlayerPageLayout.pages(artworkViewMode: .replaceStandardControls),
            [.speed, .artwork, .chapters]
        )
    }

    func test_pages_add_insertsArtworkBetweenSpeedAndMedia() {
        XCTAssertEqual(
            WatchPlayerPageLayout.pages(artworkViewMode: .add),
            [.speed, .artwork, .media, .chapters]
        )
    }

    func test_mainControls_replaceOpensArtwork() {
        XCTAssertEqual(
            WatchPlayerPageLayout.mainControlsPage(artworkViewMode: .replaceStandardControls),
            .artwork
        )
        XCTAssertEqual(WatchPlayerPageLayout.mainControlsPage(artworkViewMode: .off), .media)
        XCTAssertEqual(WatchPlayerPageLayout.mainControlsPage(artworkViewMode: .add), .media)
    }

    func test_resolve_keepsValidPage_fallsBackWhenRemoved() {
        XCTAssertEqual(
            WatchPlayerPageLayout.resolve(.chapters, artworkViewMode: .off),
            .chapters
        )
        XCTAssertEqual(
            WatchPlayerPageLayout.resolve(.media, artworkViewMode: .replaceStandardControls),
            .artwork
        )
        XCTAssertEqual(
            WatchPlayerPageLayout.resolve(.artwork, artworkViewMode: .off),
            .media
        )
    }

    func test_swipeRight_exitsPlayer() {
        XCTAssertEqual(
            WatchPlayerSwipeResolver.action(
                horizontal: 50,
                vertical: 5,
                allowsVerticalPaging: true
            ),
            .exitPlayer
        )
    }

    func test_swipeLeft_doesNotExitPlayer() {
        XCTAssertEqual(
            WatchPlayerSwipeResolver.action(
                horizontal: -50,
                vertical: 5,
                allowsVerticalPaging: true
            ),
            .none
        )
    }

    func test_verticalSwipes_changePagesOnlyWhenEnabled() {
        XCTAssertEqual(
            WatchPlayerSwipeResolver.action(
                horizontal: 0,
                vertical: 50,
                allowsVerticalPaging: true
            ),
            .previousPage
        )
        XCTAssertEqual(
            WatchPlayerSwipeResolver.action(
                horizontal: 0,
                vertical: -50,
                allowsVerticalPaging: true
            ),
            .nextPage
        )
        XCTAssertEqual(
            WatchPlayerSwipeResolver.action(
                horizontal: 0,
                vertical: -50,
                allowsVerticalPaging: false
            ),
            .none
        )
    }
}

//
//  CoverSearchPastePolicyTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class CoverSearchPastePolicyTests: XCTestCase {

    func testShouldAutoPasteWhenClipboardChangedWithImage() {
        XCTAssertTrue(
            CoverSearchPastePolicy.shouldAutoPaste(
                isAwaitingCoverSearchPaste: true,
                pasteboardChangeCountAtSearch: 3,
                currentChangeCount: 4,
                hasImageOnPasteboard: true
            )
        )
    }

    func testShouldNotAutoPasteWhenNotAwaiting() {
        XCTAssertFalse(
            CoverSearchPastePolicy.shouldAutoPaste(
                isAwaitingCoverSearchPaste: false,
                pasteboardChangeCountAtSearch: 3,
                currentChangeCount: 4,
                hasImageOnPasteboard: true
            )
        )
    }

    func testShouldNotAutoPasteWhenClipboardUnchanged() {
        XCTAssertFalse(
            CoverSearchPastePolicy.shouldAutoPaste(
                isAwaitingCoverSearchPaste: true,
                pasteboardChangeCountAtSearch: 3,
                currentChangeCount: 3,
                hasImageOnPasteboard: true
            )
        )
    }

    func testShouldNotAutoPasteWhenClipboardChangedWithoutImage() {
        XCTAssertFalse(
            CoverSearchPastePolicy.shouldAutoPaste(
                isAwaitingCoverSearchPaste: true,
                pasteboardChangeCountAtSearch: 3,
                currentChangeCount: 4,
                hasImageOnPasteboard: false
            )
        )
    }

    func testShouldEndAwaitingWhenClipboardChangedWithoutImage() {
        XCTAssertTrue(
            CoverSearchPastePolicy.shouldEndAwaitingPaste(
                isAwaitingCoverSearchPaste: true,
                pasteboardChangeCountAtSearch: 3,
                currentChangeCount: 4
            )
        )
    }
}

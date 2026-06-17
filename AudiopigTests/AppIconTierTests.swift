//
//  AppIconTierTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class AppIconTierTests: XCTestCase {

    func testOriginalTierIsAlwaysUnlockedWithNilAlternateName() {
        XCTAssertTrue(AppIconTier.original.isAlwaysUnlocked)
        XCTAssertNil(AppIconTier.original.alternateIconName)
        XCTAssertEqual(AppIconTier.original.galleryImageName, "Gallery-Original")
    }

    func testHourTiersMapToAlternateIconAndGalleryNames() {
        XCTAssertEqual(AppIconTier.h100.requiredHours, 100)
        XCTAssertEqual(AppIconTier.h100.requiredSeconds, 360_000, accuracy: 0.001)
        XCTAssertEqual(AppIconTier.h100.alternateIconName, "AppIcon-100h")
        XCTAssertEqual(AppIconTier.h100.galleryImageName, "Gallery-100h")
        XCTAssertEqual(AppIconTier.h1500.label, "1500 Hours")
    }
}

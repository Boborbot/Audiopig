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
        XCTAssertEqual(AppIconTier.h1000.alternateIconName, "AppIcon-1000h")
        XCTAssertEqual(AppIconTier.h2000.alternateIconName, "AppIcon-2000h")
        XCTAssertEqual(AppIconTier.h2500.requiredHours, 2500)
        XCTAssertEqual(AppIconTier.h2500.alternateIconName, "AppIcon-2500h")
    }
}

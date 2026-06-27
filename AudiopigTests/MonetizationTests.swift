//
//  MonetizationTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class MonetizationTests: XCTestCase {

    func test_paragraphBreaks_requiresPlusAccess() {
        XCTAssertTrue(PremiumFeature.paragraphBreaks.requiresPlusAccess)
    }

    func test_watchArtworkView_requiresPlusAccess() {
        XCTAssertTrue(PremiumFeature.watchArtworkView.requiresPlusAccess)
    }

    func test_plusGated_containsPremiumFeatures() {
        XCTAssertEqual(
            PremiumFeature.plusGated,
            [.paragraphBreaks, .watchArtworkView, .subtitles, .eq]
        )
    }

    func test_hasPremiumAccess_grantsParagraphBreaksWhenEntitled() {
        XCTAssertTrue(hasPremiumAccess(to: .paragraphBreaks, hasPlusEntitlement: true))
    }

    func test_hasPremiumAccess_deniesParagraphBreaksWithoutEntitlement() {
        XCTAssertFalse(hasPremiumAccess(to: .paragraphBreaks, hasPlusEntitlement: false))
    }

    func test_hasPremiumAccess_grantsWatchArtworkViewWhenEntitled() {
        XCTAssertTrue(hasPremiumAccess(to: .watchArtworkView, hasPlusEntitlement: true))
    }

    func test_hasPremiumAccess_deniesWatchArtworkViewWithoutEntitlement() {
        XCTAssertFalse(hasPremiumAccess(to: .watchArtworkView, hasPlusEntitlement: false))
    }

    func test_subtitles_requiresPlusAccess() {
        XCTAssertTrue(PremiumFeature.subtitles.requiresPlusAccess)
    }

    func test_hasPremiumAccess_grantsSubtitlesWhenEntitled() {
        XCTAssertTrue(hasPremiumAccess(to: .subtitles, hasPlusEntitlement: true))
    }

    func test_hasPremiumAccess_deniesSubtitlesWithoutEntitlement() {
        XCTAssertFalse(hasPremiumAccess(to: .subtitles, hasPlusEntitlement: false))
    }

    func test_eq_requiresPlusAccess() {
        XCTAssertTrue(PremiumFeature.eq.requiresPlusAccess)
    }

    func test_hasPremiumAccess_grantsEQWhenEntitled() {
        XCTAssertTrue(hasPremiumAccess(to: .eq, hasPlusEntitlement: true))
    }

    func test_hasPremiumAccess_deniesEQWithoutEntitlement() {
        XCTAssertFalse(hasPremiumAccess(to: .eq, hasPlusEntitlement: false))
    }

    func test_productIdentifiers_plusMonthly() {
        XCTAssertEqual(ProductIdentifiers.plusMonthly, "com.nitay.Audiopig.plus.monthly")
    }

    func test_productIdentifiers_allIncludesSubscriptionAndTips() {
        XCTAssertTrue(ProductIdentifiers.all.contains(ProductIdentifiers.plusMonthly))
        XCTAssertTrue(ProductIdentifiers.all.contains(ProductIdentifiers.tipCoffee))
        XCTAssertTrue(ProductIdentifiers.all.contains(ProductIdentifiers.tipLunch))
        XCTAssertTrue(ProductIdentifiers.all.contains(ProductIdentifiers.tipRent))
        XCTAssertEqual(ProductIdentifiers.all.count, 4)
    }

    func test_tipTier_productIDs() {
        XCTAssertEqual(TipTier.coffee.productID, ProductIdentifiers.tipCoffee)
        XCTAssertEqual(TipTier.lunch.productID, ProductIdentifiers.tipLunch)
        XCTAssertEqual(TipTier.rent.productID, ProductIdentifiers.tipRent)
    }

    func test_tipTier_initFromProductID() {
        XCTAssertEqual(TipTier(productID: ProductIdentifiers.tipCoffee), .coffee)
        XCTAssertEqual(TipTier(productID: ProductIdentifiers.tipLunch), .lunch)
        XCTAssertEqual(TipTier(productID: ProductIdentifiers.tipRent), .rent)
        XCTAssertNil(TipTier(productID: "com.example.unknown"))
    }

    func test_tipTier_rentDisplayNameAndThankYouPhrase() {
        XCTAssertEqual(TipTier.rent.title, "Today's Rent")
        XCTAssertEqual(TipTier.rent.systemImage, "house.fill")
        XCTAssertEqual(TipTier.rent.thankYouPhrase, "today's rent")
    }
}

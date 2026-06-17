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

    func test_plusGated_containsParagraphBreaksOnly() {
        XCTAssertEqual(PremiumFeature.plusGated, [.paragraphBreaks])
    }

    func test_hasPremiumAccess_grantsParagraphBreaksWhenEntitled() {
        XCTAssertTrue(hasPremiumAccess(to: .paragraphBreaks, hasPlusEntitlement: true))
    }

    func test_hasPremiumAccess_deniesParagraphBreaksWithoutEntitlement() {
        XCTAssertFalse(hasPremiumAccess(to: .paragraphBreaks, hasPlusEntitlement: false))
    }

    func test_productIdentifiers_plusMonthly() {
        XCTAssertEqual(ProductIdentifiers.plusMonthly, "com.nitay.Audiopig.plus.monthly")
    }

    func test_productIdentifiers_allIncludesSubscriptionAndTips() {
        XCTAssertTrue(ProductIdentifiers.all.contains(ProductIdentifiers.plusMonthly))
        XCTAssertTrue(ProductIdentifiers.all.contains(ProductIdentifiers.tipCoffee))
        XCTAssertTrue(ProductIdentifiers.all.contains(ProductIdentifiers.tipLunch))
        XCTAssertTrue(ProductIdentifiers.all.contains(ProductIdentifiers.tipSponsor))
        XCTAssertEqual(ProductIdentifiers.all.count, 4)
    }

    func test_tipTier_productIDs() {
        XCTAssertEqual(TipTier.coffee.productID, ProductIdentifiers.tipCoffee)
        XCTAssertEqual(TipTier.lunch.productID, ProductIdentifiers.tipLunch)
        XCTAssertEqual(TipTier.sponsor.productID, ProductIdentifiers.tipSponsor)
    }

    func test_tipTier_initFromProductID() {
        XCTAssertEqual(TipTier(productID: ProductIdentifiers.tipCoffee), .coffee)
        XCTAssertEqual(TipTier(productID: ProductIdentifiers.tipLunch), .lunch)
        XCTAssertEqual(TipTier(productID: ProductIdentifiers.tipSponsor), .sponsor)
        XCTAssertNil(TipTier(productID: "com.example.unknown"))
    }
}

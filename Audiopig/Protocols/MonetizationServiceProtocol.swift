//
//  MonetizationServiceProtocol.swift
//  Audiopig
//

import Foundation
import StoreKit

enum MonetizationError: LocalizedError {
    case verificationFailed
    case productUnavailable
    case userCancelled
    case pending
    case unknown

    var errorDescription: String? {
        switch self {
        case .verificationFailed:
            "Purchase could not be verified. Please try again."
        case .productUnavailable:
            "This product is not available right now."
        case .userCancelled:
            nil
        case .pending:
            "Your purchase is pending approval."
        case .unknown:
            "Something went wrong. Please try again."
        }
    }
}

/// StoreKit 2 monetization boundary for subscriptions and consumable tips.
@MainActor
protocol MonetizationServiceProtocol: AnyObject {
    var hasPlusSubscription: Bool { get }
    var isEligibleForIntroOffer: Bool { get }
    var isInTrialPeriod: Bool { get }
    var subscriptionExpirationDate: Date? { get }
    var plusDisplayPrice: String? { get }
    var plusRenewalDescription: String? { get }

    func displayPrice(for tier: TipTier) -> String?

    func hasAccess(to feature: PremiumFeature) -> Bool
    func refreshEntitlements() async
    func loadProducts() async
    func purchasePlus() async throws
    func purchaseTip(_ tier: TipTier) async throws
    func restorePurchases() async throws
    func startTransactionListener()
}

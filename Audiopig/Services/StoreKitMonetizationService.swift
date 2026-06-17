//
//  StoreKitMonetizationService.swift
//  Audiopig
//

import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class StoreKitMonetizationService: MonetizationServiceProtocol {

    // MARK: - QA

    #if DEBUG
    /// When `true`, every Plus-gated feature is available without a subscription.
    static let unlockAllPremiumForQA = true
    #else
    static let unlockAllPremiumForQA = false
    #endif

    private(set) var hasPlusSubscription = false
    private(set) var isEligibleForIntroOffer = true
    private(set) var isInTrialPeriod = false
    private(set) var subscriptionExpirationDate: Date?

    private(set) var plusDisplayPrice: String?
    private(set) var plusRenewalDescription: String?

    @ObservationIgnored
    private var plusProduct: Product?

    @ObservationIgnored
    private var tipProductsByTier: [TipTier: Product] = [:]

    @ObservationIgnored
    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - Access

    func hasAccess(to feature: PremiumFeature) -> Bool {
        if Self.unlockAllPremiumForQA { return true }
        return hasPremiumAccess(to: feature, hasPlusEntitlement: hasPlusSubscription)
    }

    func displayPrice(for tier: TipTier) -> String? {
        tipProductsByTier[tier]?.displayPrice
    }

    // MARK: - Lifecycle

    func startTransactionListener() {
        transactionListenerTask?.cancel()
        transactionListenerTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                await self.handleTransactionUpdate(update)
            }
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        var expiration: Date?
        var trial = false

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.checkVerified(result) else { continue }
            guard transaction.productID == ProductIdentifiers.plusMonthly else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }

            entitled = true
            expiration = transaction.expirationDate
            if transaction.offerType == .introductory {
                trial = true
            }
        }

        hasPlusSubscription = entitled
        subscriptionExpirationDate = expiration
        isInTrialPeriod = trial
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: ProductIdentifiers.all)
            plusProduct = products.first { $0.id == ProductIdentifiers.plusMonthly }
            plusDisplayPrice = plusProduct?.displayPrice
            plusRenewalDescription = Self.renewalDescription(for: plusProduct)

            if let plusProduct {
                isEligibleForIntroOffer = await plusProduct.subscription?.isEligibleForIntroOffer ?? false
            }

            var tips: [TipTier: Product] = [:]
            for tier in TipTier.allCases {
                if let product = products.first(where: { $0.id == tier.productID }) {
                    tips[tier] = product
                }
            }
            tipProductsByTier = tips
        } catch {
            plusProduct = nil
            plusDisplayPrice = nil
            plusRenewalDescription = nil
            tipProductsByTier = [:]
        }
    }

    // MARK: - Purchases

    func purchasePlus() async throws {
        guard let product = plusProduct else { throw MonetizationError.productUnavailable }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await refreshEntitlements()
            await transaction.finish()
        case .userCancelled:
            throw MonetizationError.userCancelled
        case .pending:
            throw MonetizationError.pending
        @unknown default:
            throw MonetizationError.unknown
        }
    }

    func purchaseTip(_ tier: TipTier) async throws {
        guard let product = tipProductsByTier[tier] else {
            throw MonetizationError.productUnavailable
        }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.checkVerified(verification)
            await transaction.finish()
        case .userCancelled:
            throw MonetizationError.userCancelled
        case .pending:
            throw MonetizationError.pending
        @unknown default:
            throw MonetizationError.unknown
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    // MARK: - Private

    private func handleTransactionUpdate(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? Self.checkVerified(result) else { return }

        if transaction.productID == ProductIdentifiers.plusMonthly {
            await refreshEntitlements()
        }

        await transaction.finish()
    }

    private static func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw MonetizationError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private static func renewalDescription(for product: Product?) -> String? {
        guard let product, let subscription = product.subscription else { return nil }

        let price = product.displayPrice
        let period = subscription.subscriptionPeriod.unit.localizedDescription
        if let intro = subscription.introductoryOffer, intro.paymentMode == .freeTrial {
            let trialPeriod = localizedPeriod(intro.period)
            return "Free for \(trialPeriod), then \(price)/\(period). Auto-renews until cancelled."
        }
        return "\(price)/\(period). Auto-renews until cancelled."
    }

    private static func localizedPeriod(_ period: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day: unit = period.value == 1 ? "day" : "days"
        case .week: unit = period.value == 1 ? "week" : "weeks"
        case .month: unit = period.value == 1 ? "month" : "months"
        case .year: unit = period.value == 1 ? "year" : "years"
        @unknown default: unit = "period"
        }
        return period.value == 1 ? "1 \(unit)" : "\(period.value) \(unit)"
    }
}

// MARK: - Subscription period copy

private extension Product.SubscriptionPeriod.Unit {
    var localizedDescription: String {
        switch self {
        case .day: "day"
        case .week: "week"
        case .month: "month"
        case .year: "year"
        @unknown default: "period"
        }
    }
}

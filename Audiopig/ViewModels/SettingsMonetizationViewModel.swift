//
//  SettingsMonetizationViewModel.swift
//  Audiopig
//

import Foundation
import Observation

@MainActor
@Observable
final class SettingsMonetizationViewModel {

    private(set) var isProcessing = false
    private(set) var errorMessage: String?
    private(set) var thankYouTier: TipTier?

    private let monetization: any MonetizationServiceProtocol

    init(monetization: any MonetizationServiceProtocol) {
        self.monetization = monetization
    }

    var plusStatusLine: String {
        if monetization.isInTrialPeriod, let end = monetization.subscriptionExpirationDate {
            let formatted = Self.mediumDateFormatter.string(from: end)
            return "Trial ends \(formatted)"
        }
        if monetization.hasPlusSubscription {
            return "Active"
        }
        return "Not subscribed"
    }

    var showsSubscribeAction: Bool {
        !monetization.hasPlusSubscription
    }

    var plusDisplayPrice: String? {
        monetization.plusDisplayPrice
    }

    func onAppear() async {
        await monetization.loadProducts()
        await monetization.refreshEntitlements()
    }

    func subscribeToPlus() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await monetization.purchasePlus()
        } catch MonetizationError.userCancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        do {
            try await monetization.restorePurchases()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func purchaseTip(_ tier: TipTier) async {
        isProcessing = true
        errorMessage = nil
        thankYouTier = nil
        defer { isProcessing = false }

        do {
            try await monetization.purchaseTip(tier)
            thankYouTier = tier
        } catch MonetizationError.userCancelled {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func displayPrice(for tier: TipTier) -> String? {
        monetization.displayPrice(for: tier)
    }

    func dismissThankYou() {
        thankYouTier = nil
    }

    private static let mediumDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

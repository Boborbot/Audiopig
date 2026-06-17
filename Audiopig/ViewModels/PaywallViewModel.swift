//
//  PaywallViewModel.swift
//  Audiopig
//

import Foundation
import Observation

@MainActor
@Observable
final class PaywallViewModel {

    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    private let monetization: any MonetizationServiceProtocol

    init(monetization: any MonetizationServiceProtocol) {
        self.monetization = monetization
    }

    var headline: String { "Find Paragraph Breaks" }

    var bodyCopy: String {
        "Detects silence in the last few minutes so you can jump back to where you drifted off."
    }

    var primaryCTATitle: String {
        if monetization.isEligibleForIntroOffer {
            return "Try free for 7 days"
        }
        if let price = monetization.plusDisplayPrice {
            return "Subscribe for \(price)/mo"
        }
        return "Subscribe"
    }

    var renewalDisclosure: String? {
        monetization.plusRenewalDescription
    }

    func onAppear() async {
        await monetization.loadProducts()
    }

    func purchasePlus() async -> Bool {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            try await monetization.purchasePlus()
            return monetization.hasAccess(to: .paragraphBreaks)
        } catch MonetizationError.userCancelled {
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func restorePurchases() async -> Bool {
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }

        do {
            try await monetization.restorePurchases()
            return monetization.hasAccess(to: .paragraphBreaks)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

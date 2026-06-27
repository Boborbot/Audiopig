//
//  PaywallViewModel.swift
//  Audiopig
//

import Foundation
import Observation

@MainActor
@Observable
final class PaywallViewModel {

    enum Feature {
        case paragraphBreaks
        case subtitles
    }

    private(set) var isPurchasing = false
    private(set) var errorMessage: String?

    private let monetization: any MonetizationServiceProtocol
    private let feature: Feature

    init(monetization: any MonetizationServiceProtocol, feature: Feature = .paragraphBreaks) {
        self.monetization = monetization
        self.feature = feature
    }

    var headline: String {
        switch feature {
        case .paragraphBreaks:
            return "Smart Rewind"
        case .subtitles:
            return "Live Subtitles"
        }
    }

    var bodyCopy: String {
        switch feature {
        case .paragraphBreaks:
            return "Look Far and Look Near scan silence in the minutes before you drifted off so you can jump back to a natural break."
        case .subtitles:
            return "Generate on-device subtitles near where you are listening, fill gaps in partial transcriptions, or transcribe an entire book in the background."
        }
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
            return monetization.hasAccess(to: feature == .subtitles ? .subtitles : .paragraphBreaks)
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
            return monetization.hasAccess(to: feature == .subtitles ? .subtitles : .paragraphBreaks)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

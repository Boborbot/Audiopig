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
        case eq
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
        case .eq:
            return "Speech EQ"
        }
    }

    var bodyCopy: String {
        switch feature {
        case .paragraphBreaks:
            return "Look Far and Look Near scan silence in the minutes before you drifted off so you can jump back to a natural break."
        case .subtitles:
            return "Generate on-device subtitles near where you are listening, fill gaps in partial transcriptions, or transcribe an entire book in the background."
        case .eq:
            return "Shape dialogue with speech-tuned EQ presets so narrators stay clear in noisy environments."
        }
    }

    private var premiumFeature: PremiumFeature {
        switch feature {
        case .paragraphBreaks:
            return .paragraphBreaks
        case .subtitles:
            return .subtitles
        case .eq:
            return .eq
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
            return monetization.hasAccess(to: premiumFeature)
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
            return monetization.hasAccess(to: premiumFeature)
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

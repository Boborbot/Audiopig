//
//  ProductIdentifiers.swift
//  AudiopigShared
//

import Foundation

/// App Store product identifiers for Audiopig monetization.
public enum ProductIdentifiers {
    public static let plusMonthly = "com.nitay.Audiopig.plus.monthly"
    public static let tipCoffee = "com.nitay.Audiopig.tip.coffee"
    public static let tipLunch = "com.nitay.Audiopig.tip.lunch"
    public static let tipSponsor = "com.nitay.Audiopig.tip.sponsor"

    public static let allTips: [String] = [tipCoffee, tipLunch, tipSponsor]

    public static let all: [String] = [plusMonthly] + allTips
}

/// Consumable tip tiers for the Feed a Student section.
public enum TipTier: String, CaseIterable, Identifiable, Sendable {
    case coffee
    case lunch
    case sponsor

    public var id: String { rawValue }

    public var productID: String {
        switch self {
        case .coffee: ProductIdentifiers.tipCoffee
        case .lunch: ProductIdentifiers.tipLunch
        case .sponsor: ProductIdentifiers.tipSponsor
        }
    }

    public var title: String {
        switch self {
        case .coffee: "Coffee"
        case .lunch: "Lunch"
        case .sponsor: "Sponsor"
        }
    }

    public var subtitle: String {
        switch self {
        case .coffee: "A small thank-you"
        case .lunch: "Fuel for a coding session"
        case .sponsor: "Generous support"
        }
    }

    public var systemImage: String {
        switch self {
        case .coffee: "cup.and.saucer.fill"
        case .lunch: "takeoutbag.and.cup.and.straw.fill"
        case .sponsor: "heart.fill"
        }
    }

    public init?(productID: String) {
        switch productID {
        case ProductIdentifiers.tipCoffee: self = .coffee
        case ProductIdentifiers.tipLunch: self = .lunch
        case ProductIdentifiers.tipSponsor: self = .sponsor
        default: return nil
        }
    }
}

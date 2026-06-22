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
    public static let tipRent = "com.nitay.Audiopig.tip.rent"

    public static let allTips: [String] = [tipCoffee, tipLunch, tipRent]

    public static let all: [String] = [plusMonthly] + allTips
}

/// Consumable tip tiers for the Feed a Student section.
public enum TipTier: String, CaseIterable, Identifiable, Sendable {
    case coffee
    case lunch
    case rent

    public var id: String { rawValue }

    public var productID: String {
        switch self {
        case .coffee: ProductIdentifiers.tipCoffee
        case .lunch: ProductIdentifiers.tipLunch
        case .rent: ProductIdentifiers.tipRent
        }
    }

    public var title: String {
        switch self {
        case .coffee: "Coffee"
        case .lunch: "Lunch"
        case .rent: "Today's Rent"
        }
    }

    public var subtitle: String {
        switch self {
        case .coffee: "A small thank-you"
        case .lunch: "Fuel for a coding session"
        case .rent: "Helps keep the lights on"
        }
    }

    public var systemImage: String {
        switch self {
        case .coffee: "cup.and.saucer.fill"
        case .lunch: "takeoutbag.and.cup.and.straw.fill"
        case .rent: "house.fill"
        }
    }

    /// Lowercased phrase for thank-you copy (e.g. "your coffee tip").
    public var thankYouPhrase: String {
        switch self {
        case .coffee: "coffee"
        case .lunch: "lunch"
        case .rent: "today's rent"
        }
    }

    public init?(productID: String) {
        switch productID {
        case ProductIdentifiers.tipCoffee: self = .coffee
        case ProductIdentifiers.tipLunch: self = .lunch
        case ProductIdentifiers.tipRent: self = .rent
        default: return nil
        }
    }
}

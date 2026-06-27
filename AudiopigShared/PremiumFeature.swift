//
//  PremiumFeature.swift
//  AudiopigShared
//

import Foundation

/// Premium capabilities gated behind AudioPig Plus (subscription or free trial).
public enum PremiumFeature: String, CaseIterable, Sendable {
    case paragraphBreaks
    case watchArtworkView
    case subtitles
}

public extension PremiumFeature {

    /// Features that require an active Plus subscription or introductory trial.
    static let plusGated: Set<PremiumFeature> = [.paragraphBreaks, .watchArtworkView, .subtitles]

    /// Whether this feature is unlocked only with AudioPig Plus.
    var requiresPlusAccess: Bool {
        Self.plusGated.contains(self)
    }
}

/// Maps subscription state to per-feature access (pure logic for tests).
public func hasPremiumAccess(
    to feature: PremiumFeature,
    hasPlusEntitlement: Bool
) -> Bool {
    guard feature.requiresPlusAccess else { return true }
    return hasPlusEntitlement
}

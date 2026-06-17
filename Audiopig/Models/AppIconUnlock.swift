//
//  AppIconUnlock.swift
//  Audiopig
//
//  Represents a newly unlocked app icon — either an achievement or a secret achievement.
//

import Foundation

enum AppIconUnlock: Equatable, Identifiable {
    case achievement(AppIconTier)
    case secret(SecretAchievement)

    var id: String {
        switch self {
        case .achievement(let tier): return "tier-\(tier.rawValue)"
        case .secret(let achievement): return "secret-\(achievement.rawValue)"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .achievement(let tier): return tier.alternateIconName
        case .secret(let achievement): return achievement.iconName
        }
    }

    var label: String {
        switch self {
        case .achievement(let tier): return tier.label
        case .secret(let achievement): return achievement.label
        }
    }

    var unlockDescription: String {
        switch self {
        case .achievement(let tier): return tier.unlockDescription
        case .secret(let achievement): return achievement.unlockDescription
        }
    }

    var overlayTitle: String {
        switch self {
        case .achievement: return "Achievement Unlocked!"
        case .secret:      return "Secret Achievement!"
        }
    }

    var isSecret: Bool {
        if case .secret = self { return true }
        return false
    }
}

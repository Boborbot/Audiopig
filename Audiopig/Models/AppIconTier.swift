//
//  AppIconTier.swift
//  Audiopig
//
//  Defines the earning thresholds for unlockable app icons.
//  Each tier requires a cumulative number of hours listened across
//  finished audiobooks. Once unlocked, the user can apply that icon
//  from the Stats screen.
//

import Foundation

enum AppIconTier: Int, CaseIterable, Identifiable {
    case h10  = 0
    case h20  = 1
    case h50  = 2
    case h100 = 3
    case h200 = 4
    case h500 = 5

    var id: Int { rawValue }

    /// Hours of finished-book listening required to unlock this tier.
    var requiredHours: Int {
        switch self {
        case .h10:  return 10
        case .h20:  return 20
        case .h50:  return 50
        case .h100: return 100
        case .h200: return 200
        case .h500: return 500
        }
    }

    var requiredSeconds: TimeInterval { Double(requiredHours) * 3_600 }

    /// Asset catalog alternate icon name (matches appiconset folder name).
    var iconName: String { "AppIcon-\(requiredHours)h" }

    /// Short display label shown in the icon gallery and unlock overlay.
    var label: String { "\(requiredHours)h Club" }

    /// Unlock description shown in the overlay body.
    var unlockDescription: String {
        "You've listened to over \(requiredHours) hours of finished audiobooks!"
    }
}

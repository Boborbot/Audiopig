//
//  AppIconTier.swift
//  Audiopig
//
//  Hour-based achievements that unlock alternate app icons.
//  Each tier requires cumulative hours listened across all audiobooks.
//

import Foundation

enum AppIconTier: Int, CaseIterable, Identifiable {
    case original = 6
    case h10  = 0
    case h20  = 1
    case h50  = 2
    case h100 = 3
    case h200 = 4
    case h500  = 5
    case h1000 = 7
    case h1500 = 8
    case h2000 = 9
    case h2500 = 10

    var id: Int { rawValue }

    /// Available from the start — the default app icon.
    var isAlwaysUnlocked: Bool {
        if case .original = self { return true }
        return false
    }

    /// Hours of listening required to unlock this tier.
    var requiredHours: Int {
        switch self {
        case .original: return 0
        case .h10:  return 10
        case .h20:  return 20
        case .h50:  return 50
        case .h100: return 100
        case .h200: return 200
        case .h500:  return 500
        case .h1000: return 1000
        case .h1500: return 1500
        case .h2000: return 2000
        case .h2500: return 2500
        }
    }

    var requiredSeconds: TimeInterval { Double(requiredHours) * 3_600 }

    /// Alternate icon name passed to `setAlternateIconName`. `nil` restores the default icon.
    var alternateIconName: String? {
        switch self {
        case .original: return nil
        default:          return "AppIcon-\(requiredHours)h"
        }
    }

    /// Gallery thumbnail in Assets.xcassets (matches imageset folder name).
    var galleryImageName: String {
        switch self {
        case .original: return "Gallery-Original"
        default:        return "Gallery-\(requiredHours)h"
        }
    }

    /// Short display label shown in the gallery and unlock overlay.
    var label: String {
        switch self {
        case .original: return "Original"
        default:        return "\(requiredHours) Hours"
        }
    }

    /// Subtitle shown beneath the label in the gallery card.
    var gallerySubtitle: String {
        switch self {
        case .original: return "Default"
        default:        return "\(requiredHours)h"
        }
    }

    /// Unlock description shown in the overlay body.
    var unlockDescription: String {
        switch self {
        case .original:
            return "The classic Audiopig icon."
        default:
            return "You've listened for over \(requiredHours) hours!"
        }
    }
}

//
//  AppIconManager.swift
//  Audiopig
//
//  Manages unlockable app icon tiers.
//
//  Unlock state and the active icon selection are persisted in UserDefaults.
//  Call `checkForNewUnlocks(totalFinishedSeconds:)` after every book-finish
//  event — it returns the highest newly unlocked tier (if any) so callers can
//  trigger a celebration overlay.
//
//  Calling `applyIcon(_:)` invokes `UIApplication.setAlternateIconName`, which
//  shows a standard system confirmation sheet. Pass `nil` to revert to the
//  default icon.
//

import Observation
import UIKit

@MainActor
@Observable
final class AppIconManager {

    // MARK: - UserDefaults keys

    private static let unlockedKey = "appicons.unlocked.rawValues"
    private static let activeKey   = "appicons.active.rawValue"

    // MARK: - State

    private(set) var unlockedRawValues: Set<Int>
    private(set) var activeRawValue: Int?   // nil  →  default app icon

    // MARK: - Derived

    var unlockedTiers: [AppIconTier] {
        AppIconTier.allCases.filter { unlockedRawValues.contains($0.rawValue) }
    }

    var activeTier: AppIconTier? {
        activeRawValue.flatMap { AppIconTier(rawValue: $0) }
    }

    func isUnlocked(_ tier: AppIconTier) -> Bool {
        unlockedRawValues.contains(tier.rawValue)
    }

    func isActive(_ tier: AppIconTier) -> Bool {
        activeRawValue == tier.rawValue
    }

    // MARK: - Init

    init() {
        let saved = UserDefaults.standard.array(forKey: Self.unlockedKey) as? [Int] ?? []
        unlockedRawValues = Set(saved)
        activeRawValue = UserDefaults.standard.object(forKey: Self.activeKey) as? Int
    }

    // MARK: - Unlock check

    /// Inspects `totalFinishedSeconds` against all tier thresholds.
    /// Marks any newly crossed tiers as unlocked and persists the change.
    /// Returns the **highest** newly unlocked tier, or `nil` if nothing changed.
    func checkForNewUnlocks(totalFinishedSeconds: TimeInterval) -> AppIconTier? {
        var highestNew: AppIconTier? = nil
        for tier in AppIconTier.allCases {
            guard totalFinishedSeconds >= tier.requiredSeconds else { continue }
            guard !unlockedRawValues.contains(tier.rawValue)   else { continue }
            unlockedRawValues.insert(tier.rawValue)
            highestNew = tier
        }
        if highestNew != nil {
            UserDefaults.standard.set(Array(unlockedRawValues), forKey: Self.unlockedKey)
        }
        return highestNew
    }

    // MARK: - Apply icon

    /// Switches the springboard icon to the given tier.
    /// Pass `nil` to restore the default icon.
    /// The system shows a native confirmation sheet — this cannot be suppressed.
    func applyIcon(_ tier: AppIconTier?) {
        let iconName = tier?.iconName
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                activeRawValue = tier?.rawValue
                if let raw = tier?.rawValue {
                    UserDefaults.standard.set(raw, forKey: Self.activeKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: Self.activeKey)
                }
            }
        }
    }

    /// Convenience: revert to the default icon.
    func applyDefaultIcon() { applyIcon(nil) }
}

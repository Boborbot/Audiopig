//
//  AppIconManager.swift
//  Audiopig
//
//  Manages unlockable app icon tiers and secret achievement icons.
//
//  Unlock state and the active icon selection are persisted in UserDefaults.
//  Call `checkForNewUnlocks(...)` after every book-finish event — it returns
//  any newly unlocked icons so callers can trigger celebration overlays.
//
//  Calling `applyIcon(named:)` invokes `UIApplication.setAlternateIconName`, which
//  shows a standard system confirmation sheet. Pass `nil` to revert to the default icon.
//

import Observation
import UIKit

@MainActor
@Observable
final class AppIconManager {

    // MARK: - UserDefaults keys

    private static let unlockedTierKey    = "appicons.unlocked.rawValues"
    private static let unlockedSecretKey  = "appicons.secrets.unlocked.rawValues"
    private static let activeIconNameKey  = "appicons.active.iconName"
    private static let legacyActiveKey    = "appicons.active.rawValue"

    // MARK: - State

    private(set) var unlockedTierRawValues: Set<Int>
    private(set) var unlockedSecretRawValues: Set<String>
    private(set) var activeIconName: String?

    // MARK: - Derived

    var unlockedTiers: [AppIconTier] {
        AppIconTier.allCases.filter { unlockedTierRawValues.contains($0.rawValue) }
    }

    var unlockedSecrets: [SecretAchievement] {
        SecretAchievement.allCases.filter { unlockedSecretRawValues.contains($0.rawValue) }
    }

    var activeTier: AppIconTier? {
        guard let activeIconName else { return nil }
        return AppIconTier.allCases.first { $0.iconName == activeIconName }
    }

    var activeSecret: SecretAchievement? {
        guard let activeIconName else { return nil }
        return SecretAchievement.allCases.first { $0.iconName == activeIconName }
    }

    func isUnlocked(_ tier: AppIconTier) -> Bool {
        unlockedTierRawValues.contains(tier.rawValue)
    }

    func isUnlocked(_ achievement: SecretAchievement) -> Bool {
        unlockedSecretRawValues.contains(achievement.rawValue)
    }

    func isActive(_ tier: AppIconTier) -> Bool {
        activeIconName == tier.iconName
    }

    func isActive(_ achievement: SecretAchievement) -> Bool {
        activeIconName == achievement.iconName
    }

    // MARK: - Init

    init() {
        let savedTiers = UserDefaults.standard.array(forKey: Self.unlockedTierKey) as? [Int] ?? []
        unlockedTierRawValues = Set(savedTiers)

        let savedSecrets = UserDefaults.standard.stringArray(forKey: Self.unlockedSecretKey) ?? []
        unlockedSecretRawValues = Set(savedSecrets)

        if let iconName = UserDefaults.standard.string(forKey: Self.activeIconNameKey) {
            activeIconName = iconName
        } else if let legacyRaw = UserDefaults.standard.object(forKey: Self.legacyActiveKey) as? Int,
                  let tier = AppIconTier(rawValue: legacyRaw) {
            activeIconName = tier.iconName
            UserDefaults.standard.set(tier.iconName, forKey: Self.activeIconNameKey)
            UserDefaults.standard.removeObject(forKey: Self.legacyActiveKey)
        } else {
            activeIconName = nil
        }
    }

    // MARK: - Unlock check

    /// Inspects listening totals and the latest finish event for newly unlocked icons.
    /// Returns all newly unlocked icons (hour-club tiers first, then secrets).
    func checkForNewUnlocks(
        totalFinishedSeconds: TimeInterval,
        finishEvent: BookFinishEvent? = nil
    ) -> [AppIconUnlock] {
        var newlyUnlocked: [AppIconUnlock] = []

        for tier in AppIconTier.allCases {
            guard totalFinishedSeconds >= tier.requiredSeconds else { continue }
            guard !unlockedTierRawValues.contains(tier.rawValue) else { continue }
            unlockedTierRawValues.insert(tier.rawValue)
            newlyUnlocked.append(.hourClub(tier))
        }

        if let finishEvent {
            for achievement in SecretAchievement.allCases {
                guard !unlockedSecretRawValues.contains(achievement.rawValue) else { continue }
                guard achievement.isUnlocked(by: finishEvent) else { continue }
                unlockedSecretRawValues.insert(achievement.rawValue)
                newlyUnlocked.append(.secret(achievement))
            }
        }

        if !newlyUnlocked.isEmpty {
            persistUnlockState()
        }

        return newlyUnlocked
    }

    // MARK: - Apply icon

    func applyIcon(_ tier: AppIconTier) {
        applyIcon(named: tier.iconName)
    }

    func applyIcon(_ achievement: SecretAchievement) {
        applyIcon(named: achievement.iconName)
    }

    /// Switches the springboard icon. Pass `nil` to restore the default icon.
    /// The system shows a native confirmation sheet — this cannot be suppressed.
    func applyIcon(named iconName: String?) {
        UIApplication.shared.setAlternateIconName(iconName) { [weak self] error in
            guard error == nil else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                activeIconName = iconName
                if let iconName {
                    UserDefaults.standard.set(iconName, forKey: Self.activeIconNameKey)
                } else {
                    UserDefaults.standard.removeObject(forKey: Self.activeIconNameKey)
                }
            }
        }
    }

    /// Convenience: revert to the default icon.
    func applyDefaultIcon() { applyIcon(named: nil) }

    // MARK: - Private

    private func persistUnlockState() {
        UserDefaults.standard.set(Array(unlockedTierRawValues), forKey: Self.unlockedTierKey)
        UserDefaults.standard.set(Array(unlockedSecretRawValues), forKey: Self.unlockedSecretKey)
    }
}

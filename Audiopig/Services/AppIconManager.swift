//
//  AppIconManager.swift
//  Audiopig
//
//  Manages unlockable achievement icons and secret achievement icons.
//
//  Unlock state and the active icon selection are persisted in UserDefaults.
//  Call `checkForNewUnlocks(...)` when listening totals change — it returns
//  any newly unlocked icons so callers can trigger celebration overlays.
//  Hour tiers use cumulative listening time; secret achievements still require
//  a book-finish event.
//

import Observation
import UIKit

@MainActor
@Observable
final class AppIconManager {

    // MARK: - QA

    #if DEBUG
    private static let qaUnlockAllKey = "appicons.qa.unlockAll"

    /// Opt-in via `UserDefaults` (`appicons.qa.unlockAll`). Off by default.
    /// Gallery preview only — `applyIcon` still requires a persisted unlock.
    static var unlockAllIconsForQA: Bool {
        UserDefaults.standard.bool(forKey: qaUnlockAllKey)
    }
    #else
    static let unlockAllIconsForQA = false
    #endif

    var treatsAllIconsAsUnlocked: Bool { Self.unlockAllIconsForQA }

    // MARK: - UserDefaults keys

    private static let unlockedTierKey    = "appicons.unlocked.rawValues"
    private static let unlockedSecretKey  = "appicons.secrets.unlocked.rawValues"
    private static let activeIconNameKey  = "appicons.active.iconName"
    private static let legacyActiveKey    = "appicons.active.rawValue"

    // MARK: - State

    private let userDefaults: UserDefaults
    private(set) var unlockedTierRawValues: Set<Int>
    private(set) var unlockedSecretRawValues: Set<String>
    private(set) var activeIconName: String?

    // MARK: - Derived

    var unlockedTiers: [AppIconTier] {
        AppIconTier.allCases.filter { isUnlocked($0) }
    }

    var unlockedSecrets: [SecretAchievement] {
        SecretAchievement.allCases.filter { isUnlocked($0) }
    }

    var activeTier: AppIconTier? {
        if activeIconName == nil { return .original }
        return AppIconTier.allCases.first { $0.alternateIconName == activeIconName }
    }

    var activeSecret: SecretAchievement? {
        guard let activeIconName else { return nil }
        return SecretAchievement.allCases.first { $0.iconName == activeIconName }
    }

    func isUnlocked(_ tier: AppIconTier) -> Bool {
        if Self.unlockAllIconsForQA { return true }
        return hasEarnedUnlock(tier)
    }

    func isUnlocked(_ achievement: SecretAchievement) -> Bool {
        if Self.unlockAllIconsForQA { return true }
        return hasEarnedUnlock(achievement)
    }

    private func hasEarnedUnlock(_ tier: AppIconTier) -> Bool {
        if tier.isAlwaysUnlocked { return true }
        return unlockedTierRawValues.contains(tier.rawValue)
    }

    private func hasEarnedUnlock(_ achievement: SecretAchievement) -> Bool {
        unlockedSecretRawValues.contains(achievement.rawValue)
    }

    func isActive(_ tier: AppIconTier) -> Bool {
        switch tier {
        case .original: return activeIconName == nil
        default:        return activeIconName == tier.alternateIconName
        }
    }

    func isActive(_ achievement: SecretAchievement) -> Bool {
        activeIconName == achievement.iconName
    }

    // MARK: - Init

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let savedTiers = userDefaults.array(forKey: Self.unlockedTierKey) as? [Int] ?? []
        unlockedTierRawValues = Set(savedTiers)

        let savedSecrets = userDefaults.stringArray(forKey: Self.unlockedSecretKey) ?? []
        unlockedSecretRawValues = Set(savedSecrets)

        if let iconName = userDefaults.string(forKey: Self.activeIconNameKey) {
            activeIconName = iconName
        } else if let legacyRaw = userDefaults.object(forKey: Self.legacyActiveKey) as? Int,
                  let tier = AppIconTier(rawValue: legacyRaw) {
            activeIconName = tier.alternateIconName
            if let iconName = tier.alternateIconName {
                userDefaults.set(iconName, forKey: Self.activeIconNameKey)
            } else {
                userDefaults.removeObject(forKey: Self.activeIconNameKey)
            }
            userDefaults.removeObject(forKey: Self.legacyActiveKey)
        } else {
            activeIconName = nil
        }
    }

    // MARK: - Unlock check

    /// Inspects listening totals and the latest finish event for newly unlocked icons.
    /// Returns all newly unlocked icons (achievements first, then secrets).
    func checkForNewUnlocks(
        totalListenedSeconds: TimeInterval,
        finishEvent: BookFinishEvent? = nil
    ) -> [AppIconUnlock] {
        var newlyUnlocked: [AppIconUnlock] = []

        for tier in AppIconTier.allCases where !tier.isAlwaysUnlocked {
            guard totalListenedSeconds >= tier.requiredSeconds else { continue }
            guard !unlockedTierRawValues.contains(tier.rawValue) else { continue }
            unlockedTierRawValues.insert(tier.rawValue)
            newlyUnlocked.append(.achievement(tier))
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
        guard hasEarnedUnlock(tier), !isActive(tier) else { return }
        applyIcon(named: tier.alternateIconName)
    }

    func applyIcon(_ achievement: SecretAchievement) {
        guard hasEarnedUnlock(achievement), !isActive(achievement) else { return }
        applyIcon(named: achievement.iconName)
    }

    /// Switches the springboard icon. Pass `nil` to restore the default icon.
    func applyIcon(named iconName: String?) {
        AlternateIconSwitcher.setIcon(named: iconName) { [weak self] success in
            guard success else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                activeIconName = iconName
                if let iconName {
                    self.userDefaults.set(iconName, forKey: Self.activeIconNameKey)
                } else {
                    self.userDefaults.removeObject(forKey: Self.activeIconNameKey)
                }
            }
        }
    }

    /// Convenience: revert to the default icon.
    func applyDefaultIcon() { applyIcon(named: nil) }

    // MARK: - Private

    private func persistUnlockState() {
        userDefaults.set(Array(unlockedTierRawValues), forKey: Self.unlockedTierKey)
        userDefaults.set(Array(unlockedSecretRawValues), forKey: Self.unlockedSecretKey)
    }
}

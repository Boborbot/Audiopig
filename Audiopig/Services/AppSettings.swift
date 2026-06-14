//
//  AppSettings.swift
//  Audiopig
//
//  Persistent user preferences. Each property is backed by a private @ObservationIgnored
//  store that reads from UserDefaults on first access and writes back through the setter,
//  while still participating in @Observable change tracking via manual access/withMutation.
//

import Foundation
import Observation
import SwiftUI

// MARK: - AppAppearance

/// The user's preferred color scheme override.
///
/// `.system` follows the device's system setting (default).
/// `.light` and `.dark` force the corresponding scheme regardless of system.
enum AppAppearance: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    /// Human-readable label shown in the Settings picker.
    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// The `ColorScheme` to pass to SwiftUI's `preferredColorScheme` modifier.
    /// Returns `nil` for `.system` so SwiftUI defers to the device setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - AppSettings

@Observable
final class AppSettings {

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let defaultSpeed         = "settings.defaultSpeed"
        static let skipForwardInterval  = "settings.skipForwardInterval"
        static let skipBackwardInterval = "settings.skipBackwardInterval"
        static let appearance           = "settings.appearance"
        static let autoDeleteOnFinish   = "settings.autoDeleteOnFinish"
        static let trackReadingStats    = "settings.trackReadingStats"
        static let autoExportOnFinish   = "settings.autoExportOnFinish"
        static let autoExportOnDelete   = "settings.autoExportOnDelete"
        static let sleepTimerOption     = "settings.sleepTimerOption"
        static let sleepTimerExpiry     = "settings.sleepTimerExpiry"
    }

    // MARK: - Backing Stores (not observed individually)

    @ObservationIgnored
    private var _defaultSpeed: Float = {
        let stored = UserDefaults.standard.float(forKey: Keys.defaultSpeed)
        return stored > 0 ? stored : 1.0
    }()

    @ObservationIgnored
    private var _skipForwardInterval: TimeInterval = {
        let stored = UserDefaults.standard.double(forKey: Keys.skipForwardInterval)
        return stored > 0 ? stored : 15.0
    }()

    @ObservationIgnored
    private var _skipBackwardInterval: TimeInterval = {
        let stored = UserDefaults.standard.double(forKey: Keys.skipBackwardInterval)
        return stored > 0 ? stored : 15.0
    }()

    @ObservationIgnored
    private var _appearance: AppAppearance = {
        guard let raw = UserDefaults.standard.string(forKey: Keys.appearance),
              let stored = AppAppearance(rawValue: raw) else { return .system }
        return stored
    }()

    @ObservationIgnored
    private var _autoDeleteOnFinish: Bool = {
        // Key must exist; absence means the default (false) applies.
        guard UserDefaults.standard.object(forKey: Keys.autoDeleteOnFinish) != nil else { return false }
        return UserDefaults.standard.bool(forKey: Keys.autoDeleteOnFinish)
    }()

    @ObservationIgnored
    private var _trackReadingStats: Bool = {
        guard UserDefaults.standard.object(forKey: Keys.trackReadingStats) != nil else { return true }
        return UserDefaults.standard.bool(forKey: Keys.trackReadingStats)
    }()

    @ObservationIgnored
    private var _autoExportOnFinish: Bool = {
        guard UserDefaults.standard.object(forKey: Keys.autoExportOnFinish) != nil else { return true }
        return UserDefaults.standard.bool(forKey: Keys.autoExportOnFinish)
    }()

    @ObservationIgnored
    private var _autoExportOnDelete: Bool = {
        guard UserDefaults.standard.object(forKey: Keys.autoExportOnDelete) != nil else { return true }
        return UserDefaults.standard.bool(forKey: Keys.autoExportOnDelete)
    }()

    // MARK: - Observable Properties

    /// Default playback rate applied when an audiobook is first loaded. Range [0.5, 3.0].
    var defaultSpeed: Float {
        get {
            access(keyPath: \.defaultSpeed)
            return _defaultSpeed
        }
        set {
            withMutation(keyPath: \.defaultSpeed) {
                _defaultSpeed = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.defaultSpeed)
            }
        }
    }

    /// Seconds used for the skip-forward action.
    var skipForwardInterval: TimeInterval {
        get {
            access(keyPath: \.skipForwardInterval)
            return _skipForwardInterval
        }
        set {
            withMutation(keyPath: \.skipForwardInterval) {
                _skipForwardInterval = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.skipForwardInterval)
            }
        }
    }

    /// Seconds used for the skip-backward action.
    var skipBackwardInterval: TimeInterval {
        get {
            access(keyPath: \.skipBackwardInterval)
            return _skipBackwardInterval
        }
        set {
            withMutation(keyPath: \.skipBackwardInterval) {
                _skipBackwardInterval = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.skipBackwardInterval)
            }
        }
    }

    /// When `true`, a book is automatically deleted from the library after being marked finished.
    /// Default: `false`.
    var autoDeleteOnFinish: Bool {
        get {
            access(keyPath: \.autoDeleteOnFinish)
            return _autoDeleteOnFinish
        }
        set {
            withMutation(keyPath: \.autoDeleteOnFinish) {
                _autoDeleteOnFinish = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.autoDeleteOnFinish)
            }
        }
    }

    /// When `true`, a `FinishedRecord` is created every time a book is marked finished.
    /// Default: `true`.
    var trackReadingStats: Bool {
        get {
            access(keyPath: \.trackReadingStats)
            return _trackReadingStats
        }
        set {
            withMutation(keyPath: \.trackReadingStats) {
                _trackReadingStats = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.trackReadingStats)
            }
        }
    }

    /// When `true`, bookmarks are exported to the Files app when a book is marked finished.
    /// Default: `true`.
    var autoExportOnFinish: Bool {
        get {
            access(keyPath: \.autoExportOnFinish)
            return _autoExportOnFinish
        }
        set {
            withMutation(keyPath: \.autoExportOnFinish) {
                _autoExportOnFinish = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.autoExportOnFinish)
            }
        }
    }

    /// When `true`, bookmarks are exported to the Files app when a book is removed from the library.
    /// Default: `true`.
    var autoExportOnDelete: Bool {
        get {
            access(keyPath: \.autoExportOnDelete)
            return _autoExportOnDelete
        }
        set {
            withMutation(keyPath: \.autoExportOnDelete) {
                _autoExportOnDelete = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.autoExportOnDelete)
            }
        }
    }

    /// The user's preferred color scheme. `.system` follows the device setting.
    var appearance: AppAppearance {
        get {
            access(keyPath: \.appearance)
            return _appearance
        }
        set {
            withMutation(keyPath: \.appearance) {
                _appearance = newValue
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.appearance)
            }
        }
    }

    // MARK: - Sleep Timer Session Persistence

    /// Persists the active sleep timer so it survives an app kill.
    ///
    /// - For `.minutes` timers the absolute expiry date is stored so that time elapsed
    ///   while the app was killed is correctly subtracted on restore.
    /// - For `.endOfChapter` the option name is stored without a time component.
    /// - For `.off` any previous persisted state is cleared.
    func saveSleepTimer(option: String, expiryDate: Date?) {
        UserDefaults.standard.set(option, forKey: Keys.sleepTimerOption)
        if let expiry = expiryDate {
            UserDefaults.standard.set(expiry, forKey: Keys.sleepTimerExpiry)
        } else {
            UserDefaults.standard.removeObject(forKey: Keys.sleepTimerExpiry)
        }
    }

    /// Returns the persisted sleep timer state, or `nil` if none is saved or it has expired.
    ///
    /// Returns a tuple of `(optionRawString, remainingSeconds)`.
    /// For `.endOfChapter` remaining is always 0.
    /// Returns `nil` when the persisted timer has already elapsed.
    func loadSleepTimer() -> (option: String, remaining: TimeInterval)? {
        guard let raw = UserDefaults.standard.string(forKey: Keys.sleepTimerOption) else { return nil }
        if raw == "endOfChapter" {
            return ("endOfChapter", 0)
        }
        if raw.hasPrefix("minutes") {
            guard let expiry = UserDefaults.standard.object(forKey: Keys.sleepTimerExpiry) as? Date else { return nil }
            let remaining = expiry.timeIntervalSinceNow
            guard remaining > 0 else {
                clearSleepTimer()
                return nil
            }
            return (raw, remaining)
        }
        return nil
    }

    /// Clears any persisted sleep timer state.
    func clearSleepTimer() {
        UserDefaults.standard.removeObject(forKey: Keys.sleepTimerOption)
        UserDefaults.standard.removeObject(forKey: Keys.sleepTimerExpiry)
    }
}

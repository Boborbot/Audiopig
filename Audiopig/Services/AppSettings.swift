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
}

//
//  VoiceBoostLevel.swift
//  AudiopigShared
//

import Foundation

/// Discrete Voice Boost intensity. `off` bypasses processing; other levels scale quiet-passage lift.
public enum VoiceBoostLevel: Int, CaseIterable, Sendable, Identifiable, Hashable {
    case off = 0
    case light = 1
    case balanced = 2
    case strong = 3

    public var id: Int { rawValue }

    public var label: String {
        switch self {
        case .off: "Off"
        case .light: "Light"
        case .balanced: "Balanced"
        case .strong: "Strong"
        }
    }

    public var isEnabled: Bool { self != .off }

    /// Max gain multiplier applied to quiet narration. Strong matches the original single-level boost.
    public var maxBoost: Float {
        let fullBoost: Float = 1.28
        switch self {
        case .off:
            return 1
        case .light:
            return 1 + (fullBoost - 1) * 0.15
        case .balanced:
            return 1 + (fullBoost - 1) * 0.60
        case .strong:
            return fullBoost
        }
    }

    public static func validated(_ raw: Int) -> VoiceBoostLevel {
        VoiceBoostLevel(rawValue: raw) ?? .off
    }

    /// Maps legacy on/off storage to the closest modern level.
    public static func migrated(fromLegacyEnabled enabled: Bool) -> VoiceBoostLevel {
        enabled ? .balanced : .off
    }
}

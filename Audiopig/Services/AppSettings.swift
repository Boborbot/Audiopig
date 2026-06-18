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

@MainActor
@Observable
final class AppSettings {
    private static func normalizedSpeed(_ speed: Float) -> Float {
        WatchSpeedRange.normalized(speed)
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let defaultSpeed         = "settings.defaultSpeed"
        static let universalSpeedEnabled = "settings.universalSpeedEnabled"
        static let universalSpeedValue   = "settings.universalSpeedValue"
        static let speedPreset1         = "settings.speedPreset1"
        static let speedPreset2         = "settings.speedPreset2"
        static let speedPreset3         = "settings.speedPreset3"
        static let skipForwardInterval  = "settings.skipForwardInterval"
        static let skipBackwardInterval = "settings.skipBackwardInterval"
        static let lullLookbackWindow   = "settings.lullLookbackWindow"
        static let lullSkipRecentWindow = "settings.lullSkipRecentWindow"
        static let appearance           = "settings.appearance"
        static let orientationLock      = "settings.orientationLock"
        static let autoDeleteOnFinish   = "settings.autoDeleteOnFinish"
        static let trackReadingStats    = "settings.trackReadingStats"
        static let autoExportOnFinish   = "settings.autoExportOnFinish"
        static let autoExportOnDelete   = "settings.autoExportOnDelete"
        static let sleepTimerOption     = "settings.sleepTimerOption"
        static let sleepTimerExpiry     = "settings.sleepTimerExpiry"
        static let watchArtworkSkipGestures = "settings.watchArtworkSkipGestures"
        static let watchArtworkViewMode = "settings.watchArtworkViewMode"
        static let librarySortOrder         = "settings.librarySortOrder"
        static let libraryBookFilter        = "settings.libraryBookFilter"
        static let librarySortDirection     = "settings.librarySortDirection"
        static let playbackTimelineScope    = "settings.playbackTimelineScope"
    }

    // MARK: - Backing Stores (not observed individually)

    @ObservationIgnored
    private var _defaultSpeed: Float = {
        let stored = UserDefaults.standard.float(forKey: Keys.defaultSpeed)
        return stored > 0 ? stored : 1.0
    }()

    @ObservationIgnored
    private var _universalSpeedEnabled: Bool = {
        guard UserDefaults.standard.object(forKey: Keys.universalSpeedEnabled) != nil else { return false }
        return UserDefaults.standard.bool(forKey: Keys.universalSpeedEnabled)
    }()

    @ObservationIgnored
    private var _universalSpeedValue: Float = {
        let stored = UserDefaults.standard.float(forKey: Keys.universalSpeedValue)
        return stored > 0 ? stored : 0
    }()

    @ObservationIgnored
    private var _speedPreset1: Float = {
        let stored = UserDefaults.standard.float(forKey: Keys.speedPreset1)
        return stored > 0 ? stored : 1.0
    }()

    @ObservationIgnored
    private var _speedPreset2: Float = {
        let stored = UserDefaults.standard.float(forKey: Keys.speedPreset2)
        return stored > 0 ? stored : 1.2
    }()

    @ObservationIgnored
    private var _speedPreset3: Float = {
        let stored = UserDefaults.standard.float(forKey: Keys.speedPreset3)
        return stored > 0 ? stored : 1.5
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
    private var _lullLookbackWindow: TimeInterval = {
        let stored = UserDefaults.standard.double(forKey: Keys.lullLookbackWindow)
        // Default: 5 minutes. Clamp to [30s, 15m].
        let value = stored > 0 ? stored : 300.0
        return min(max(value, 30.0), 15.0 * 60.0)
    }()

    @ObservationIgnored
    private var _lullSkipRecentWindow: TimeInterval = {
        let stored = UserDefaults.standard.double(forKey: Keys.lullSkipRecentWindow)
        // Default: 30 seconds. Clamp to [0s, 5m].
        let value = stored >= 0 ? stored : 30.0
        return min(max(value, 0.0), 5.0 * 60.0)
    }()

    @ObservationIgnored
    private var _appearance: AppAppearance = {
        guard let raw = UserDefaults.standard.string(forKey: Keys.appearance),
              let stored = AppAppearance(rawValue: raw) else { return .system }
        return stored
    }()

    @ObservationIgnored
    private var _orientationLock: Bool = {
        guard UserDefaults.standard.object(forKey: Keys.orientationLock) != nil else { return false }
        return UserDefaults.standard.bool(forKey: Keys.orientationLock)
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

    @ObservationIgnored
    private var _watchArtworkSkipGesturesEnabled: Bool = {
        guard UserDefaults.standard.object(forKey: Keys.watchArtworkSkipGestures) != nil else { return false }
        return UserDefaults.standard.bool(forKey: Keys.watchArtworkSkipGestures)
    }()

    @ObservationIgnored
    private var _watchArtworkViewMode: WatchArtworkViewMode = {
        guard let raw = UserDefaults.standard.string(forKey: Keys.watchArtworkViewMode),
              let mode = WatchArtworkViewMode(rawValue: raw) else {
            return .off
        }
        return mode
    }()

    @ObservationIgnored
    private var _librarySortOrder: LibrarySortOrder = {
        guard let raw = UserDefaults.standard.string(forKey: Keys.librarySortOrder),
              let order = LibrarySortOrder(rawValue: raw) else {
            return .recentlyListened
        }
        return order
    }()

    @ObservationIgnored
    private var _libraryBookFilter: LibraryBookFilter = {
        guard let raw = UserDefaults.standard.string(forKey: Keys.libraryBookFilter),
              let filter = LibraryBookFilter(rawValue: raw) else {
            return .all
        }
        return filter
    }()

    @ObservationIgnored
    private var _librarySortDirection: LibrarySortDirection = {
        guard let raw = UserDefaults.standard.string(forKey: Keys.librarySortDirection),
              let direction = LibrarySortDirection(rawValue: raw) else {
            return .descending
        }
        return direction
    }()

    @ObservationIgnored
    private var _playbackTimelineScope: PlaybackTimelineScope = {
        guard let raw = UserDefaults.standard.string(forKey: Keys.playbackTimelineScope),
              let scope = PlaybackTimelineScope(rawValue: raw) else {
            return .entireBook
        }
        return scope
    }()

    // MARK: - Observable Properties

    /// Default playback rate applied when an audiobook is first loaded. Range [0.25, 4.0].
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

    /// When enabled, playback speed is global across all books (and synced to Watch).
    /// Default: `false`.
    var universalPlaybackSpeedEnabled: Bool {
        get {
            access(keyPath: \.universalPlaybackSpeedEnabled)
            return _universalSpeedEnabled
        }
        set {
            withMutation(keyPath: \.universalPlaybackSpeedEnabled) {
                _universalSpeedEnabled = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.universalSpeedEnabled)
            }
            if newValue, universalPlaybackSpeed <= 0 {
                universalPlaybackSpeed = defaultSpeed
            }
        }
    }

    /// The universal playback speed value when `universalPlaybackSpeedEnabled` is on.
    ///
    /// Stored even while universal mode is off so it can be toggled on without losing the last value.
    var universalPlaybackSpeed: Float {
        get {
            access(keyPath: \.universalPlaybackSpeed)
            return _universalSpeedValue
        }
        set {
            let normalized = Self.normalizedSpeed(newValue)
            withMutation(keyPath: \.universalPlaybackSpeed) {
                _universalSpeedValue = normalized
                UserDefaults.standard.set(normalized, forKey: Keys.universalSpeedValue)
            }
        }
    }

    /// Playback-speed preset button 1 used in the phone + watch players. Range [0.25, 4.0].
    var speedPreset1: Float {
        get {
            access(keyPath: \.speedPreset1)
            return _speedPreset1
        }
        set {
            let normalized = Self.normalizedSpeed(newValue)
            withMutation(keyPath: \.speedPreset1) {
                _speedPreset1 = normalized
                UserDefaults.standard.set(normalized, forKey: Keys.speedPreset1)
            }
        }
    }

    /// Playback-speed preset button 2 used in the phone + watch players. Range [0.25, 4.0].
    var speedPreset2: Float {
        get {
            access(keyPath: \.speedPreset2)
            return _speedPreset2
        }
        set {
            let normalized = Self.normalizedSpeed(newValue)
            withMutation(keyPath: \.speedPreset2) {
                _speedPreset2 = normalized
                UserDefaults.standard.set(normalized, forKey: Keys.speedPreset2)
            }
        }
    }

    /// Playback-speed preset button 3 used in the phone + watch players. Range [0.25, 4.0].
    var speedPreset3: Float {
        get {
            access(keyPath: \.speedPreset3)
            return _speedPreset3
        }
        set {
            let normalized = Self.normalizedSpeed(newValue)
            withMutation(keyPath: \.speedPreset3) {
                _speedPreset3 = normalized
                UserDefaults.standard.set(normalized, forKey: Keys.speedPreset3)
            }
        }
    }

    /// The three preset speeds, normalized and sorted ascending for consistent UI.
    var speedPresets: [Float] {
        let presets = [speedPreset1, speedPreset2, speedPreset3]
        return presets.sorted()
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

    /// How far back lull detection searches for breaks (paragraph breaks feature).
    ///
    /// Clamped to [30 s, 15 min]. Default: 5 min.
    var lullLookbackWindow: TimeInterval {
        get {
            access(keyPath: \.lullLookbackWindow)
            return _lullLookbackWindow
        }
        set {
            let clamped = min(max(newValue, 30.0), 15.0 * 60.0)
            withMutation(keyPath: \.lullLookbackWindow) {
                _lullLookbackWindow = clamped
                UserDefaults.standard.set(clamped, forKey: Keys.lullLookbackWindow)
            }
        }
    }

    /// How much recent audio to exclude from lull detection.
    ///
    /// Clamped to [0 s, 5 min]. Default: 30 s.
    var lullSkipRecentWindow: TimeInterval {
        get {
            access(keyPath: \.lullSkipRecentWindow)
            return _lullSkipRecentWindow
        }
        set {
            let clamped = min(max(newValue, 0.0), 5.0 * 60.0)
            withMutation(keyPath: \.lullSkipRecentWindow) {
                _lullSkipRecentWindow = clamped
                UserDefaults.standard.set(clamped, forKey: Keys.lullSkipRecentWindow)
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

    /// When `true`, the app is locked to portrait orientation.
    /// Default: `false`.
    var orientationLock: Bool {
        get {
            access(keyPath: \.orientationLock)
            return _orientationLock
        }
        set {
            withMutation(keyPath: \.orientationLock) {
                _orientationLock = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.orientationLock)
            }
        }
    }

    /// When `true`, double/triple-tap on the Watch player artwork zone skips forward/back.
    /// Default: `false`.
    var watchArtworkSkipGesturesEnabled: Bool {
        get {
            access(keyPath: \.watchArtworkSkipGesturesEnabled)
            return _watchArtworkSkipGesturesEnabled
        }
        set {
            withMutation(keyPath: \.watchArtworkSkipGesturesEnabled) {
                _watchArtworkSkipGesturesEnabled = newValue
                UserDefaults.standard.set(newValue, forKey: Keys.watchArtworkSkipGestures)
            }
        }
    }

    /// How the Watch player shows a dedicated artwork screen. Default: `.off`.
    var watchArtworkViewMode: WatchArtworkViewMode {
        get {
            access(keyPath: \.watchArtworkViewMode)
            return _watchArtworkViewMode
        }
        set {
            withMutation(keyPath: \.watchArtworkViewMode) {
                _watchArtworkViewMode = newValue
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.watchArtworkViewMode)
            }
        }
    }

    /// How root-level library audiobooks are ordered. Default: recently listened.
    var librarySortOrder: LibrarySortOrder {
        get {
            access(keyPath: \.librarySortOrder)
            return _librarySortOrder
        }
        set {
            withMutation(keyPath: \.librarySortOrder) {
                _librarySortOrder = newValue
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.librarySortOrder)
            }
        }
    }

    /// Which audiobooks appear in library lists. Default: all books.
    var libraryBookFilter: LibraryBookFilter {
        get {
            access(keyPath: \.libraryBookFilter)
            return _libraryBookFilter
        }
        set {
            withMutation(keyPath: \.libraryBookFilter) {
                _libraryBookFilter = newValue
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.libraryBookFilter)
            }
        }
    }

    /// Sort direction for library lists. Default: descending.
    var librarySortDirection: LibrarySortDirection {
        get {
            access(keyPath: \.librarySortDirection)
            return _librarySortDirection
        }
        set {
            withMutation(keyPath: \.librarySortDirection) {
                _librarySortDirection = newValue
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.librarySortDirection)
            }
        }
    }

    /// Whether the player timebar + lock-screen timeline use the whole book or current chapter.
    /// Default: entire book.
    var playbackTimelineScope: PlaybackTimelineScope {
        get {
            access(keyPath: \.playbackTimelineScope)
            return _playbackTimelineScope
        }
        set {
            withMutation(keyPath: \.playbackTimelineScope) {
                _playbackTimelineScope = newValue
                UserDefaults.standard.set(newValue.rawValue, forKey: Keys.playbackTimelineScope)
            }
        }
    }

    func watchSettingsSnapshot(
        hasParagraphBreaksAccess: Bool,
        hasWatchArtworkViewAccess: Bool
    ) -> WatchSettingsSnapshot {
        WatchSettingsSnapshot(
            artworkSkipGesturesEnabled: watchArtworkSkipGesturesEnabled,
            skipForwardSeconds: skipForwardInterval,
            skipBackwardSeconds: skipBackwardInterval,
            speedPresets: speedPresets,
            playbackTimelineScope: playbackTimelineScope,
            defaultSpeed: defaultSpeed,
            universalPlaybackSpeedEnabled: universalPlaybackSpeedEnabled,
            universalPlaybackSpeed: universalPlaybackSpeedEnabled ? universalPlaybackSpeed : nil,
            hasParagraphBreaksAccess: hasParagraphBreaksAccess,
            watchArtworkViewMode: watchArtworkViewMode,
            hasWatchArtworkViewAccess: hasWatchArtworkViewAccess
        )
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

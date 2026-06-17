//
//  WidgetListeningSnapshot.swift
//  AudiopigShared
//
//  Denormalized listening stats written by the app and read by the widget extension.
//  Must stay free of SwiftUI, SwiftData, and WidgetKit imports.
//

import Foundation

enum WidgetListeningSnapshot {

    static let appGroupID = "group.com.nitay.Audiopig"
    static let widgetKind = "ListeningStatsWidget"
    static let artworkWidgetKind = "ListeningArtworkWidget"
    static let allWidgetKinds = [
        widgetKind,
        artworkWidgetKind,
        WidgetWeeklyListeningSnapshot.widgetKind,
        WidgetRecentBooksSnapshot.widgetKind,
    ]
    static let coverArtworkFilename = "widget-last-cover.jpg"

    struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double
    }

    struct Theme: Equatable {
        let background: RGB
        let accent: RGB
        let primaryText: RGB
        let secondaryText: RGB

        static let fallback = Theme(
            background: RGB(red: 0x14 / 255, green: 0x15 / 255, blue: 0x18 / 255),
            accent: RGB(red: 0xF1 / 255, green: 0x84 / 255, blue: 0x70 / 255),
            primaryText: RGB(red: 1, green: 1, blue: 1),
            secondaryText: RGB(red: 0.82, green: 0.82, blue: 0.84)
        )
    }

    private enum Keys {
        static let lastPlayedTitle = "widget.lastPlayedTitle"
        static let lastPlayedAuthor = "widget.lastPlayedAuthor"
        static let lastPlayedAudiobookID = "widget.lastPlayedAudiobookID"
        static let todayDate = "widget.todayDate"
        static let todayListenedSeconds = "widget.todayListenedSeconds"
        static let snapshotUpdatedAt = "widget.snapshotUpdatedAt"
        static let themeBackgroundRed = "widget.theme.background.red"
        static let themeBackgroundGreen = "widget.theme.background.green"
        static let themeBackgroundBlue = "widget.theme.background.blue"
        static let themeAccentRed = "widget.theme.accent.red"
        static let themeAccentGreen = "widget.theme.accent.green"
        static let themeAccentBlue = "widget.theme.accent.blue"
        static let themePrimaryTextRed = "widget.theme.primaryText.red"
        static let themePrimaryTextGreen = "widget.theme.primaryText.green"
        static let themePrimaryTextBlue = "widget.theme.primaryText.blue"
        static let themeSecondaryTextRed = "widget.theme.secondaryText.red"
        static let themeSecondaryTextGreen = "widget.theme.secondaryText.green"
        static let themeSecondaryTextBlue = "widget.theme.secondaryText.blue"
    }

    struct Data: Equatable {
        let lastPlayedTitle: String
        let lastPlayedAuthor: String
        let lastPlayedAudiobookID: String?
        let todayListenedSeconds: TimeInterval
        let snapshotUpdatedAt: Date
        let theme: Theme
        let hasCoverArtwork: Bool
    }

    // MARK: - Read

    static func load() -> Data {
        let defaults = sharedDefaults()
        let title = defaults?.string(forKey: Keys.lastPlayedTitle) ?? ""
        let author = defaults?.string(forKey: Keys.lastPlayedAuthor) ?? ""
        let audiobookID = defaults?.string(forKey: Keys.lastPlayedAudiobookID)
        let todaySeconds = resolvedTodaySeconds(defaults: defaults)
        let updatedAt = defaults?.object(forKey: Keys.snapshotUpdatedAt) as? Date ?? .distantPast
        return Data(
            lastPlayedTitle: title,
            lastPlayedAuthor: author,
            lastPlayedAudiobookID: audiobookID,
            todayListenedSeconds: todaySeconds,
            snapshotUpdatedAt: updatedAt,
            theme: loadTheme(defaults: defaults),
            hasCoverArtwork: coverArtworkURL() != nil
        )
    }

    static func coverArtworkURL() -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return nil }
        let url = container.appendingPathComponent(coverArtworkFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    // MARK: - Write (app only)

    static func updateLastPlayed(title: String, author: String, audiobookID: String? = nil) {
        guard let defaults = sharedDefaults() else { return }
        defaults.set(title, forKey: Keys.lastPlayedTitle)
        defaults.set(author, forKey: Keys.lastPlayedAuthor)
        if let audiobookID {
            defaults.set(audiobookID, forKey: Keys.lastPlayedAudiobookID)
        }
        touchSnapshot(defaults)
    }

    static func saveTheme(_ theme: Theme) {
        guard let defaults = sharedDefaults() else { return }
        writeRGB(theme.background, prefix: "widget.theme.background", defaults: defaults)
        writeRGB(theme.accent, prefix: "widget.theme.accent", defaults: defaults)
        writeRGB(theme.primaryText, prefix: "widget.theme.primaryText", defaults: defaults)
        writeRGB(theme.secondaryText, prefix: "widget.theme.secondaryText", defaults: defaults)
        touchSnapshot(defaults)
    }

    static func clearCoverArtwork() {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupID
        ) else { return }
        let url = container.appendingPathComponent(coverArtworkFilename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func addTodayListening(_ delta: TimeInterval) {
        guard delta > 0, let defaults = sharedDefaults() else { return }
        rollToTodayIfNeeded(defaults: defaults)
        let current = defaults.double(forKey: Keys.todayListenedSeconds)
        defaults.set(current + delta, forKey: Keys.todayListenedSeconds)
        WidgetWeeklyListeningSnapshot.addListening(delta)
        touchSnapshot(defaults)
    }

    // MARK: - Deep links

    static func playURL(for snapshot: Data) -> URL? {
        guard let idString = snapshot.lastPlayedAudiobookID,
              let bookID = UUID(uuidString: idString) else { return nil }
        return URL(string: "audiopig://play/\(bookID.uuidString)")
    }

    // MARK: - Formatting

    /// E.g. "2.4h", "42m", "1m", "0m".
    static func formatTodayListening(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60

        if hours > 0 {
            let fractionalHours = seconds / 3600
            if minutes == 0 {
                return "\(hours)h"
            }
            return String(format: "%.1fh", fractionalHours)
        }
        if minutes > 0 { return "\(minutes)m" }
        if total > 0 { return "1m" }
        return "0m"
    }

    /// E.g. "2h24m", "42m", "1m", "0m".
    static func formatTodayListeningHoursMinutes(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        var minutes = (total % 3600) / 60
        if total > 0 && hours == 0 && minutes == 0 {
            minutes = 1
        }
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }
        return "\(minutes)m"
    }

    // MARK: - Private

    private static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    private static func todayKey(for date: Date = .now) -> String {
        Calendar.current.startOfDay(for: date).formatted(.iso8601.year().month().day())
    }

    private static func resolvedTodaySeconds(defaults: UserDefaults?) -> TimeInterval {
        guard let defaults else { return 0 }
        rollToTodayIfNeeded(defaults: defaults)
        return defaults.double(forKey: Keys.todayListenedSeconds)
    }

    private static func rollToTodayIfNeeded(defaults: UserDefaults) {
        let today = todayKey()
        let storedDay = defaults.string(forKey: Keys.todayDate)
        guard storedDay != today else { return }
        defaults.set(today, forKey: Keys.todayDate)
        defaults.set(0, forKey: Keys.todayListenedSeconds)
    }

    private static func touchSnapshot(_ defaults: UserDefaults) {
        defaults.set(Date(), forKey: Keys.snapshotUpdatedAt)
    }

    private static func loadTheme(defaults: UserDefaults?) -> Theme {
        guard let defaults,
              defaults.object(forKey: Keys.themeBackgroundRed) != nil else {
            return .fallback
        }
        return Theme(
            background: readRGB(prefix: "widget.theme.background", defaults: defaults),
            accent: readRGB(prefix: "widget.theme.accent", defaults: defaults),
            primaryText: readRGB(prefix: "widget.theme.primaryText", defaults: defaults),
            secondaryText: readRGB(prefix: "widget.theme.secondaryText", defaults: defaults)
        )
    }

    private static func writeRGB(_ rgb: RGB, prefix: String, defaults: UserDefaults) {
        defaults.set(rgb.red, forKey: "\(prefix).red")
        defaults.set(rgb.green, forKey: "\(prefix).green")
        defaults.set(rgb.blue, forKey: "\(prefix).blue")
    }

    private static func readRGB(prefix: String, defaults: UserDefaults) -> RGB {
        RGB(
            red: defaults.double(forKey: "\(prefix).red"),
            green: defaults.double(forKey: "\(prefix).green"),
            blue: defaults.double(forKey: "\(prefix).blue")
        )
    }
}

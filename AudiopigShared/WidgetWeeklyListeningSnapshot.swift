//
//  WidgetWeeklyListeningSnapshot.swift
//  AudiopigShared
//

import Foundation

enum WidgetWeeklyListeningSnapshot {

    static let widgetKind = "WeeklyListeningWidget"
    private static let daysToKeep = 7
    private static let daySecondsKey = "widget.weeklyDaySecondsJSON"

    struct DayBucket: Codable, Equatable {
        let dayKey: String
        let seconds: TimeInterval
    }

    struct Data: Equatable {
        let days: [DayBucket]
        let totalSeconds: TimeInterval
    }

    // MARK: - Read

    static func load() -> Data {
        let days = lastSevenDays()
        let total = days.reduce(0) { $0 + $1.seconds }
        return Data(days: days, totalSeconds: total)
    }

    // MARK: - Write (app only)

    static func addListening(_ delta: TimeInterval) {
        guard delta > 0, let defaults = sharedDefaults() else { return }
        var map = loadDayMap(defaults: defaults)
        pruneOldEntries(&map)
        let today = todayKey()
        map[today, default: 0] += delta
        saveDayMap(map, defaults: defaults)
    }

    // MARK: - Formatting

    /// Label under each bar, e.g. "0h", "1.5h", "3h".
    static func formatDayBarHours(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3_600
        if hours < 0.05 { return "0h" }
        if hours < 1 { return String(format: "%.1fh", hours) }
        return "\(Int(hours.rounded()))h"
    }

    /// Weekly total headline, e.g. "12h", "2.5h".
    static func formatWeeklyTotal(_ seconds: TimeInterval) -> String {
        let hours = seconds / 3_600
        if hours < 0.05 { return "0h" }
        let rounded = Int(hours.rounded())
        if hours < 10, abs(hours - Double(rounded)) > 0.05 {
            return String(format: "%.1fh", hours)
        }
        return "\(rounded)h"
    }

    // MARK: - Private

    private static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: WidgetListeningSnapshot.appGroupID)
    }

    private static func todayKey(for date: Date = .now) -> String {
        Calendar.current.startOfDay(for: date).formatted(.iso8601.year().month().day())
    }

    private static func lastSevenDays() -> [DayBucket] {
        let map = loadDayMap(defaults: sharedDefaults())
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        return (0..<daysToKeep).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) ?? startOfToday
            let key = todayKey(for: date)
            return DayBucket(dayKey: key, seconds: map[key] ?? 0)
        }
    }

    private static func loadDayMap(defaults: UserDefaults?) -> [String: TimeInterval] {
        guard let defaults,
              let data = defaults.data(forKey: daySecondsKey),
              let decoded = try? JSONDecoder().decode([String: TimeInterval].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveDayMap(_ map: [String: TimeInterval], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: daySecondsKey)
    }

    private static func pruneOldEntries(_ map: inout [String: TimeInterval]) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        guard let cutoff = calendar.date(byAdding: .day, value: -(daysToKeep - 1), to: startOfToday) else { return }
        let cutoffKey = todayKey(for: cutoff)
        map = map.filter { $0.key >= cutoffKey }
    }
}

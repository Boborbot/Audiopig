//
//  StatsListeningHistory.swift
//  AudiopigShared
//
//  Per-book daily listening history and first-listen tracking for the Stats tab.
//

import Foundation

public enum StatsListeningHistory {

    public struct WeeklyBookSlice: Equatable, Identifiable, Sendable {
        public let id: UUID
        public let title: String
        public let seconds: TimeInterval
        public let paletteIndex: Int

        public init(id: UUID, title: String, seconds: TimeInterval, paletteIndex: Int) {
            self.id = id
            self.title = title
            self.seconds = seconds
            self.paletteIndex = paletteIndex
        }
    }

    private static let daysToKeep = 7
    private static let firstListenDateKey = "stats.firstListenDate"
    private static let dayBookSecondsKey = "stats.dayBookSecondsJSON"

    // MARK: - Write (app only)

    public static func recordListening(_ delta: TimeInterval, bookID: UUID, now: Date = .now) {
        guard delta > 0, let defaults = sharedDefaults() else { return }

        if defaults.object(forKey: firstListenDateKey) == nil {
            defaults.set(now.timeIntervalSince1970, forKey: firstListenDateKey)
        }

        var map = loadDayBookMap(defaults: defaults)
        pruneOldEntries(&map, now: now)
        let today = dayKey(for: now)
        var bookMap = map[today, default: [:]]
        bookMap[bookID.uuidString, default: 0] += delta
        map[today] = bookMap
        saveDayBookMap(map, defaults: defaults)
    }

    public static func clearAll() {
        guard let defaults = sharedDefaults() else { return }
        defaults.removeObject(forKey: firstListenDateKey)
        defaults.removeObject(forKey: dayBookSecondsKey)
    }

    // MARK: - Read

    public static func firstListenDate() -> Date? {
        guard let defaults = sharedDefaults(),
              defaults.object(forKey: firstListenDateKey) != nil else {
            return nil
        }
        return Date(timeIntervalSince1970: defaults.double(forKey: firstListenDateKey))
    }

    public static func weeklySecondsByBookID(now: Date = .now, calendar: Calendar = .current) -> [UUID: TimeInterval] {
        let map = loadDayBookMap(defaults: sharedDefaults())
        let startOfToday = calendar.startOfDay(for: now)
        var totals: [UUID: TimeInterval] = [:]

        for offset in 0..<daysToKeep {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: startOfToday) else { continue }
            let key = dayKey(for: date)
            guard let bookMap = map[key] else { continue }
            for (bookIDString, seconds) in bookMap where seconds > 0 {
                guard let bookID = UUID(uuidString: bookIDString) else { continue }
                totals[bookID, default: 0] += seconds
            }
        }

        return totals
    }

    // MARK: - Pure logic

    public static func averageDailySeconds(
        totalListenedSeconds: TimeInterval,
        firstListen: Date?,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> TimeInterval {
        guard totalListenedSeconds > 0, let firstListen else { return 0 }

        let start = calendar.startOfDay(for: firstListen)
        let end = calendar.startOfDay(for: now)
        let daySpan = max(1, calendar.dateComponents([.day], from: start, to: end).day.map { $0 + 1 } ?? 1)
        return totalListenedSeconds / Double(daySpan)
    }

    /// Earliest plausible first-listen instant from tracked stats and library metadata.
    public static func earliestFirstListenDate(
        trackedFirstListen: Date?,
        bookAddedDates: [Date],
        finishedListeningDates: [Date]
    ) -> Date? {
        var candidates: [Date] = []
        if let trackedFirstListen {
            candidates.append(trackedFirstListen)
        }
        candidates.append(contentsOf: bookAddedDates)
        candidates.append(contentsOf: finishedListeningDates)
        return candidates.min()
    }

    /// Persists an earlier first-listen anchor when library history predates tracked stats.
    public static func adoptEarlierFirstListenDateIfNeeded(_ candidate: Date) {
        guard let defaults = sharedDefaults() else { return }
        if let existing = firstListenDate(), candidate >= existing {
            return
        }
        defaults.set(candidate.timeIntervalSince1970, forKey: firstListenDateKey)
    }

    public static func makeWeeklySlices(
        secondsByBookID: [UUID: TimeInterval],
        weeklyTotalSeconds: TimeInterval,
        titleForBook: (UUID) -> String,
        maxBookSlices: Int = 5
    ) -> [WeeklyBookSlice] {
        let ranked = secondsByBookID
            .filter { $0.value > 0 }
            .sorted { $0.value > $1.value }

        let trackedTotal = ranked.reduce(0.0) { $0 + $1.value }
        let unknownSeconds = max(0, weeklyTotalSeconds - trackedTotal)

        guard trackedTotal > 0 || unknownSeconds > 0 else { return [] }

        var slices: [WeeklyBookSlice] = []
        var nextColorIndex = 0

        let visibleCount = min(maxBookSlices, ranked.count)
        for (bookID, seconds) in ranked.prefix(visibleCount) {
            slices.append(
                WeeklyBookSlice(
                    id: bookID,
                    title: titleForBook(bookID),
                    seconds: seconds,
                    paletteIndex: nextAssignedColorIndex(&nextColorIndex)
                )
            )
        }

        if ranked.count > visibleCount {
            let otherSeconds = ranked.dropFirst(visibleCount).reduce(0.0) { $0 + $1.value }
            slices.append(
                WeeklyBookSlice(
                    id: otherBooksSliceID,
                    title: "Other",
                    seconds: otherSeconds,
                    paletteIndex: nextAssignedColorIndex(&nextColorIndex)
                )
            )
        }

        if unknownSeconds > 0.5 {
            slices.append(
                WeeklyBookSlice(
                    id: unknownSliceID,
                    title: "Unknown",
                    seconds: unknownSeconds,
                    paletteIndex: StatsChartPalette.unknownPaletteIndex
                )
            )
        }

        return slices
    }

    private static let unknownSliceID = UUID(uuidString: "00000000-0000-0000-0000-000000000098")!
    private static let otherBooksSliceID = UUID(uuidString: "00000000-0000-0000-0000-000000000099")!

    private static func nextAssignedColorIndex(_ next: inout Int) -> Int {
        let index = min(next, StatsChartPalette.bookColors.count - 1)
        next += 1
        return index
    }

    public static func weeklyTotalSeconds(from slices: [WeeklyBookSlice]) -> TimeInterval {
        slices.reduce(0) { $0 + $1.seconds }
    }

    // MARK: - Private

    private static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: WidgetListeningSnapshot.appGroupID)
    }

    private static func dayKey(for date: Date) -> String {
        Calendar.current.startOfDay(for: date).formatted(.iso8601.year().month().day())
    }

    private static func loadDayBookMap(defaults: UserDefaults?) -> [String: [String: TimeInterval]] {
        guard let defaults,
              let data = defaults.data(forKey: dayBookSecondsKey),
              let decoded = try? JSONDecoder().decode([String: [String: TimeInterval]].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveDayBookMap(_ map: [String: [String: TimeInterval]], defaults: UserDefaults) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: dayBookSecondsKey)
    }

    private static func pruneOldEntries(_ map: inout [String: [String: TimeInterval]], now: Date) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let cutoff = calendar.date(byAdding: .day, value: -(daysToKeep - 1), to: startOfToday) else { return }
        let cutoffKey = dayKey(for: cutoff)
        map = map.filter { $0.key >= cutoffKey }
    }
}

public enum StatsChartPalette {
    public static let unknownPaletteIndex = 100

    /// Ordered warm/cool alternation so adjacent pie slices stay visually distinct.
    public static let bookColors: [(red: Double, green: Double, blue: Double)] = [
        (0xF1 / 255, 0x84 / 255, 0x70 / 255), // coral
        (0.22, 0.57, 0.60), // teal
        (0.86, 0.62, 0.12), // amber
        (0.35, 0.40, 0.75), // indigo
        (0.75, 0.38, 0.20), // burnt orange
        (0.52, 0.28, 0.70), // purple
        (0.20, 0.58, 0.36), // forest green
    ]

    public static let unknownColor = (red: 0.62, green: 0.62, blue: 0.66)
}

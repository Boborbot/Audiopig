//
//  StatsViewModel.swift
//  Audiopig
//
//  Aggregates playback and completion statistics from SwiftData.
//  Sources from two tables:
//    • Audiobook — accumulated listening seconds for every book still in the library.
//    • FinishedRecord — immutable snapshots for books that were finished
//      (and possibly since deleted). Only books absent from the live library
//      contribute their snapshot to avoid double-counting.
//

import Observation
import SwiftData
import Foundation

@MainActor
@Observable
final class StatsViewModel {

    // MARK: - Stats

    private(set) var totalListenedSeconds: TimeInterval = 0
    private(set) var finishedBooksCount: Int = 0

    /// Total seconds listened across **finished** books only.
    private(set) var finishedListenedSeconds: TimeInterval = 0

    /// Average daily listening since the first tracked listen.
    private(set) var averageDailyListenedSeconds: TimeInterval = 0

    /// Per-book listening breakdown for the trailing seven days.
    private(set) var weeklyBookListeningSlices: [StatsListeningHistory.WeeklyBookSlice] = []

    /// Aggregate weekly listening used by the pie chart total label.
    private(set) var weeklyBookListeningTotalSeconds: TimeInterval = 0

    /// True when widget weekly totals include listening not yet split by book.
    private(set) var weeklyBookListeningIsPartial = false

    // MARK: - Formatted helpers

    /// Human-readable total listening time, e.g. "42 h 17 m" or "38 min".
    var totalListenedFormatted: String {
        formatDuration(totalListenedSeconds)
    }

    var averageDailyListenedFormatted: String {
        formatDuration(averageDailyListenedSeconds)
    }

    var weeklyBookListeningTotalFormatted: String {
        formatDuration(weeklyBookListeningTotalSeconds)
    }

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Refresh

    /// Re-queries SwiftData and recomputes all stats.
    /// Called when the Stats tab appears and whenever listening progress is persisted (at most once per minute during playback).
    func refresh() {
        let records    = (try? modelContext.fetch(FetchDescriptor<FinishedRecord>())) ?? []
        let audiobooks = (try? modelContext.fetch(FetchDescriptor<Audiobook>()))      ?? []

        let totals = ListeningStatsAggregator.compute(
            books: audiobooks.map(Self.bookInput(from:)),
            records: records.map(Self.recordInput(from:))
        )

        totalListenedSeconds = totals.totalListenedSeconds
        finishedBooksCount = totals.finishedBooksCount
        finishedListenedSeconds = totals.finishedListenedSeconds

        let firstListen = earliestFirstListenDate(
            audiobooks: audiobooks,
            records: records
        )
        if let firstListen {
            StatsListeningHistory.adoptEarlierFirstListenDateIfNeeded(firstListen)
        }
        averageDailyListenedSeconds = StatsListeningHistory.averageDailySeconds(
            totalListenedSeconds: totals.totalListenedSeconds,
            firstListen: firstListen
        )

        let trackedByBook = StatsListeningHistory.weeklySecondsByBookID()
        let widgetWeeklyTotal = WidgetWeeklyListeningSnapshot.load().totalSeconds
        weeklyBookListeningSlices = StatsListeningHistory.makeWeeklySlices(
            secondsByBookID: trackedByBook,
            weeklyTotalSeconds: widgetWeeklyTotal,
            titleForBook: { bookID in
                titleForWeeklyBook(
                    bookID: bookID,
                    audiobooks: audiobooks,
                    records: records
                )
            }
        )
        weeklyBookListeningTotalSeconds = widgetWeeklyTotal
        weeklyBookListeningIsPartial = weeklyBookListeningSlices.contains {
            $0.title == "Unknown"
        }
    }

    /// Permanently removes all reading stats from SwiftData.
    func deleteAllStats() {
        let records = (try? modelContext.fetch(FetchDescriptor<FinishedRecord>())) ?? []
        records.forEach { modelContext.delete($0) }

        let audiobooks = (try? modelContext.fetch(FetchDescriptor<Audiobook>())) ?? []
        audiobooks.forEach { $0.accumulatedListeningSeconds = 0 }

        StatsListeningHistory.clearAll()
        try? modelContext.save()
        refresh()
    }

    // MARK: - Private helpers

    private func earliestFirstListenDate(
        audiobooks: [Audiobook],
        records: [FinishedRecord]
    ) -> Date? {
        let bookAddedDates = audiobooks
            .filter { $0.accumulatedListeningSeconds > 0 }
            .map(\.effectiveAddedAt)
            .filter { $0 != .distantPast }

        let finishedListeningDates = records
            .filter { $0.listenedSeconds > 0 }
            .map(\.finishedAt)

        return StatsListeningHistory.earliestFirstListenDate(
            trackedFirstListen: StatsListeningHistory.firstListenDate(),
            bookAddedDates: bookAddedDates,
            finishedListeningDates: finishedListeningDates
        )
    }

    private func titleForWeeklyBook(
        bookID: UUID,
        audiobooks: [Audiobook],
        records: [FinishedRecord]
    ) -> String {
        if let title = audiobooks.first(where: { $0.id == bookID })?.title, !title.isEmpty {
            return title
        }
        if let title = records.first(where: { $0.audiobookID == bookID })?.title, !title.isEmpty {
            return title
        }
        return "Unknown"
    }

    private static func bookInput(from audiobook: Audiobook) -> ListeningStatsBookInput {
        ListeningStatsBookInput(
            id: audiobook.id,
            accumulatedListeningSeconds: audiobook.accumulatedListeningSeconds,
            isFinished: audiobook.isFinished
        )
    }

    private static func recordInput(from record: FinishedRecord) -> ListeningStatsFinishRecordInput {
        ListeningStatsFinishRecordInput(
            audiobookID: record.audiobookID,
            listenedSeconds: record.listenedSeconds,
            finishedAt: record.finishedAt
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 && m > 0 { return "\(h) h \(m) m" }
        if h > 0           { return "\(h) h" }
        if m > 0           { return "\(m) min" }
        if total > 0       { return "< 1 min" }
        return "0 min"
    }
}

//
//  StatsViewModel.swift
//  Audiopig
//
//  Aggregates playback and completion statistics from SwiftData.
//  Sources from two tables:
//    • Audiobook — current progress for every book still in the library.
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
    /// Used by the icon gallery progress bars (mirrors AppIconManager's unlock logic).
    private(set) var finishedListenedSeconds: TimeInterval = 0

    // MARK: - Formatted helpers

    /// Human-readable total listening time, e.g. "42 h 17 m" or "38 min".
    var totalListenedFormatted: String {
        formatDuration(totalListenedSeconds)
    }

    // MARK: - Dependencies

    private let modelContext: ModelContext

    // MARK: - Init

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        refresh()
    }

    // MARK: - Refresh

    /// Re-queries SwiftData and recomputes all stats. Call on appear.
    func refresh() {
        let records    = (try? modelContext.fetch(FetchDescriptor<FinishedRecord>())) ?? []
        let audiobooks = (try? modelContext.fetch(FetchDescriptor<Audiobook>()))      ?? []

        let libraryIDs = Set(audiobooks.map(\.id))

        // Total listened time
        // • All library books contribute their current playback position.
        // • FinishedRecords for books no longer in the library contribute the
        //   position that was snapshotted when the book was marked finished.
        let libraryTime = audiobooks.reduce(0.0) { $0 + $1.currentPlaybackTime }
        let deletedTime = records
            .filter { !libraryIDs.contains($0.audiobookID) }
            .reduce(0.0) { $0 + $1.listenedSeconds }
        totalListenedSeconds = libraryTime + deletedTime

        // Finished books count + finished-only listened time (for icon unlock progress)
        // • Books currently in the library that are finished.
        // • Books that were finished then deleted (present in FinishedRecord but
        //   absent from the live library). Union avoids double-counting books that
        //   are finished and still in the library with a FinishedRecord.
        let finishedBooks      = audiobooks.filter(\.isFinished)
        let finishedLibraryIDs = Set(finishedBooks.map(\.id))
        let finishedDeletedIDs = Set(records.map(\.audiobookID)).subtracting(libraryIDs)
        finishedBooksCount = finishedLibraryIDs.union(finishedDeletedIDs).count

        let finishedLibraryTime = finishedBooks.reduce(0.0) { $0 + $1.currentPlaybackTime }
        let finishedDeletedTime = records
            .filter { !libraryIDs.contains($0.audiobookID) }
            .reduce(0.0) { $0 + $1.listenedSeconds }
        finishedListenedSeconds = finishedLibraryTime + finishedDeletedTime
    }

    // MARK: - Private helpers

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

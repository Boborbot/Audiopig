//
//  ListeningStatsAggregator.swift
//  AudiopigShared
//
//  Pure listening-stats math shared by the Stats tab and icon-unlock checks.
//  Each audiobook contributes wall-clock listening time exactly once.
//

import Foundation

public struct ListeningStatsBookInput: Sendable, Equatable {
    public let id: UUID
    public let accumulatedListeningSeconds: TimeInterval
    public let isFinished: Bool

    public init(
        id: UUID,
        accumulatedListeningSeconds: TimeInterval,
        isFinished: Bool
    ) {
        self.id = id
        self.accumulatedListeningSeconds = accumulatedListeningSeconds
        self.isFinished = isFinished
    }
}

public struct ListeningStatsFinishRecordInput: Sendable, Equatable {
    public let audiobookID: UUID
    public let listenedSeconds: TimeInterval
    public let finishedAt: Date

    public init(
        audiobookID: UUID,
        listenedSeconds: TimeInterval,
        finishedAt: Date
    ) {
        self.audiobookID = audiobookID
        self.listenedSeconds = listenedSeconds
        self.finishedAt = finishedAt
    }
}

public enum ListeningStatsAggregator {

    public struct Totals: Equatable {
        public let totalListenedSeconds: TimeInterval
        public let finishedBooksCount: Int
        public let finishedListenedSeconds: TimeInterval

        public init(
            totalListenedSeconds: TimeInterval,
            finishedBooksCount: Int,
            finishedListenedSeconds: TimeInterval
        ) {
            self.totalListenedSeconds = totalListenedSeconds
            self.finishedBooksCount = finishedBooksCount
            self.finishedListenedSeconds = finishedListenedSeconds
        }
    }

    /// Aggregates listening time without double-counting finish snapshots.
    ///
    /// - In-library books always use live `accumulatedListeningSeconds`, even when
    ///   a matching `FinishedRecord` exists from marking the book done.
    /// - Books removed from the library contribute only their latest finish snapshot.
    public static func compute(
        books: [ListeningStatsBookInput],
        records: [ListeningStatsFinishRecordInput]
    ) -> Totals {
        let libraryIDs = Set(books.map(\.id))
        let latestDeletedRecords = latestRecordPerBook(
            records.filter { !libraryIDs.contains($0.audiobookID) }
        )

        let totalListenedSeconds = books.reduce(0.0) { $0 + $1.accumulatedListeningSeconds }
            + latestDeletedRecords.values.reduce(0.0) { $0 + $1.listenedSeconds }

        let finishedLibraryIDs = Set(books.filter(\.isFinished).map(\.id))
        let finishedDeletedIDs = Set(latestDeletedRecords.keys)
        let finishedBooksCount = finishedLibraryIDs.union(finishedDeletedIDs).count

        let finishedLibraryTime = books
            .filter(\.isFinished)
            .reduce(0.0) { $0 + $1.accumulatedListeningSeconds }
        let finishedDeletedTime = latestDeletedRecords.values
            .reduce(0.0) { $0 + $1.listenedSeconds }
        let finishedListenedSeconds = finishedLibraryTime + finishedDeletedTime

        return Totals(
            totalListenedSeconds: totalListenedSeconds,
            finishedBooksCount: finishedBooksCount,
            finishedListenedSeconds: finishedListenedSeconds
        )
    }

    static func latestRecordPerBook(
        _ records: [ListeningStatsFinishRecordInput]
    ) -> [UUID: ListeningStatsFinishRecordInput] {
        var latest: [UUID: ListeningStatsFinishRecordInput] = [:]
        for record in records {
            if let existing = latest[record.audiobookID] {
                if record.finishedAt > existing.finishedAt {
                    latest[record.audiobookID] = record
                }
            } else {
                latest[record.audiobookID] = record
            }
        }
        return latest
    }
}

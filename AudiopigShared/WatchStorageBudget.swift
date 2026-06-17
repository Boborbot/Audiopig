//
//  WatchStorageBudget.swift
//  AudiopigShared
//

import Foundation

public struct WatchStorageEntry: Sendable, Equatable {
    public let bookID: UUID
    public let byteCount: Int64
    public let lastPlayedAt: Date?
    public let transferredAt: Date

    public init(bookID: UUID, byteCount: Int64, lastPlayedAt: Date?, transferredAt: Date) {
        self.bookID = bookID
        self.byteCount = byteCount
        self.lastPlayedAt = lastPlayedAt
        self.transferredAt = transferredAt
    }
}

public enum WatchStorageBudget {
    public static let defaultBudgetBytes: Int64 = 2_147_483_648

    /// Returns book IDs to evict (oldest / least-recently-used first) until `incomingBytes` fits.
    public static func booksToEvict(
        entries: [WatchStorageEntry],
        incomingBytes: Int64,
        budget: Int64 = defaultBudgetBytes
    ) -> [UUID] {
        let currentUsage = entries.reduce(Int64(0)) { $0 + $1.byteCount }
        var remaining = currentUsage + incomingBytes - budget
        guard remaining > 0 else { return [] }

        let sorted = entries.sorted { lhs, rhs in
            let lhsKey = lhs.lastPlayedAt ?? lhs.transferredAt
            let rhsKey = rhs.lastPlayedAt ?? rhs.transferredAt
            return lhsKey < rhsKey
        }

        var evictions: [UUID] = []
        for entry in sorted {
            guard remaining > 0 else { break }
            evictions.append(entry.bookID)
            remaining -= entry.byteCount
        }
        return evictions
    }

    public static func canFit(
        entries: [WatchStorageEntry],
        incomingBytes: Int64,
        budget: Int64 = defaultBudgetBytes
    ) -> Bool {
        let currentUsage = entries.reduce(Int64(0)) { $0 + $1.byteCount }
        return currentUsage + incomingBytes <= budget
    }
}

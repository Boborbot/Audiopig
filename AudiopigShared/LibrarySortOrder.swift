//
//  LibrarySortOrder.swift
//  AudiopigShared
//

import Foundation

/// User-selectable ordering for library audiobook lists.
public enum LibrarySortOrder: String, CaseIterable, Identifiable, Sendable {
    case recentlyListened
    case dateAdded
    case timeAdded
    case title
    case author
    case fileSize
    case duration

    public var id: String { rawValue }

    public var menuTitle: String {
        switch self {
        case .recentlyListened: return "Recently Listened"
        case .dateAdded:        return "Date Added"
        case .timeAdded:        return "Time Added"
        case .title:            return "Name"
        case .author:           return "Author"
        case .fileSize:         return "Size"
        case .duration:         return "Length"
        }
    }
}

/// Lightweight audiobook fields used for pure sort logic (tests + ViewModels).
public struct LibrarySortCandidate: Sendable, Equatable {
    public let id: UUID
    public let title: String
    public let author: String
    public let duration: TimeInterval
    public let lastPlayedAt: Date?
    public let addedAt: Date
    public let fileSize: Int64

    public init(
        id: UUID,
        title: String,
        author: String,
        duration: TimeInterval,
        lastPlayedAt: Date?,
        addedAt: Date,
        fileSize: Int64
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.duration = duration
        self.lastPlayedAt = lastPlayedAt
        self.addedAt = addedAt
        self.fileSize = fileSize
    }
}

public enum LibrarySorter {
    /// Returns candidates sorted by `order`, preserving relative order only through tie-breakers.
    public static func sorted(
        _ candidates: [LibrarySortCandidate],
        by order: LibrarySortOrder
    ) -> [LibrarySortCandidate] {
        switch order {
        case .recentlyListened:
            return sortRecentlyListened(candidates)
        case .dateAdded:
            return candidates.sorted { lhs, rhs in
                let lhsDay = calendarStartOfDay(lhs.addedAt)
                let rhsDay = calendarStartOfDay(rhs.addedAt)
                if lhsDay != rhsDay { return lhsDay > rhsDay }
                if lhs.addedAt != rhs.addedAt { return lhs.addedAt > rhs.addedAt }
                return titleAscending(lhs, rhs)
            }
        case .timeAdded:
            return candidates.sorted { lhs, rhs in
                let lhsSeconds = secondsSinceStartOfDay(lhs.addedAt)
                let rhsSeconds = secondsSinceStartOfDay(rhs.addedAt)
                if lhsSeconds != rhsSeconds { return lhsSeconds > rhsSeconds }
                // Tie-break within the same time-of-day: newer day first.
                let lhsDay = calendarStartOfDay(lhs.addedAt)
                let rhsDay = calendarStartOfDay(rhs.addedAt)
                if lhsDay != rhsDay { return lhsDay > rhsDay }
                if lhs.addedAt != rhs.addedAt { return lhs.addedAt > rhs.addedAt }
                return titleAscending(lhs, rhs)
            }
        case .title:
            return candidates.sorted { titleAscending($0, $1) }
        case .author:
            return candidates.sorted { lhs, rhs in
                let authorCompare = lhs.author.localizedCaseInsensitiveCompare(rhs.author)
                if authorCompare != .orderedSame { return authorCompare == .orderedAscending }
                return titleAscending(lhs, rhs)
            }
        case .fileSize:
            return candidates.sorted { lhs, rhs in
                if lhs.fileSize != rhs.fileSize { return lhs.fileSize > rhs.fileSize }
                return titleAscending(lhs, rhs)
            }
        case .duration:
            return candidates.sorted { lhs, rhs in
                if lhs.duration != rhs.duration { return lhs.duration > rhs.duration }
                return titleAscending(lhs, rhs)
            }
        }
    }

    /// Listened books first (most recent play date), then never-played books by date added (newest first).
    private static func sortRecentlyListened(_ candidates: [LibrarySortCandidate]) -> [LibrarySortCandidate] {
        let listened = candidates
            .filter { $0.lastPlayedAt != nil }
            .sorted { lhs, rhs in
                let lhsDate = lhs.lastPlayedAt!
                let rhsDate = rhs.lastPlayedAt!
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return titleAscending(lhs, rhs)
            }

        let unlistened = candidates
            .filter { $0.lastPlayedAt == nil }
            .sorted { lhs, rhs in
                if lhs.addedAt != rhs.addedAt { return lhs.addedAt > rhs.addedAt }
                return titleAscending(lhs, rhs)
            }

        return listened + unlistened
    }

    private static func calendarStartOfDay(_ date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private static func secondsSinceStartOfDay(_ date: Date) -> Int {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = comps.hour ?? 0
        let minute = comps.minute ?? 0
        let second = comps.second ?? 0
        return (hour * 3600) + (minute * 60) + second
    }

    private static func titleAscending(_ lhs: LibrarySortCandidate, _ rhs: LibrarySortCandidate) -> Bool {
        lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
    }
}

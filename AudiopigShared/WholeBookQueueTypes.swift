//
//  WholeBookQueueTypes.swift
//  AudiopigShared
//

import Foundation

public enum WholeBookQueueEntryStatus: String, Codable, Sendable, CaseIterable {
    case queued
    case running
    case paused
    case failed
}

public struct WholeBookQueueItemSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let audiobookID: UUID
    public let title: String
    public let author: String
    public let queuePosition: Int
    public let status: WholeBookQueueEntryStatus
    public let isPreparing: Bool
    public let coverageFraction: Double
    public let completedWindows: Int
    public let totalWindows: Int
    public let progressMessage: String?
    public let failureMessage: String?

    public init(
        id: UUID,
        audiobookID: UUID,
        title: String,
        author: String,
        queuePosition: Int,
        status: WholeBookQueueEntryStatus,
        isPreparing: Bool = false,
        coverageFraction: Double,
        completedWindows: Int,
        totalWindows: Int,
        progressMessage: String?,
        failureMessage: String?
    ) {
        self.id = id
        self.audiobookID = audiobookID
        self.title = title
        self.author = author
        self.queuePosition = queuePosition
        self.status = status
        self.isPreparing = isPreparing
        self.coverageFraction = coverageFraction
        self.completedWindows = completedWindows
        self.totalWindows = totalWindows
        self.progressMessage = progressMessage
        self.failureMessage = failureMessage
    }

    public var coveragePercent: Int {
        Int((coverageFraction * 100).rounded())
    }
}

public enum WholeBookQueueSnapshotMapper {

    public static func jobState(from snapshot: WholeBookQueueItemSnapshot?) -> WholeBookSubtitleJobStateKind {
        guard let snapshot else { return .idle }
        switch snapshot.status {
        case .queued:
            return .idle
        case .running:
            if snapshot.isPreparing {
                return .preparing
            }
            return .running(
                completed: snapshot.completedWindows,
                total: max(snapshot.totalWindows, 1),
                message: snapshot.progressMessage ?? "Transcribing entire book…"
            )
        case .paused:
            return .paused(
                completed: snapshot.completedWindows,
                total: max(snapshot.totalWindows, 1)
            )
        case .failed:
            return .failed(snapshot.failureMessage ?? "Subtitle generation failed.")
        }
    }
}

/// UI-facing whole-book job state without tying to PlayerViewModel.
public enum WholeBookSubtitleJobStateKind: Equatable {
    case idle
    case preparing
    case running(completed: Int, total: Int, message: String)
    case paused(completed: Int, total: Int)
    case failed(String)

    public var isActive: Bool {
        switch self {
        case .idle, .failed: return false
        case .preparing, .running, .paused: return true
        }
    }
}

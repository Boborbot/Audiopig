//
//  WatchTransferManifest.swift
//  AudiopigShared
//

import Foundation

public struct WatchTransferManifest: Codable, Sendable, Equatable {
    public let bookID: UUID
    public let title: String
    public let author: String
    public let duration: TimeInterval
    public let chapters: [WatchChapterSummary]
    public let fileByteCount: Int64
    public let sha256: String
    public let fileExtension: String
    public let transferredAt: Date
    public let thumbnailJPEG: Data?
    public let resumePosition: TimeInterval
    public var lastPlayedAt: Date?

    public init(
        bookID: UUID,
        title: String,
        author: String,
        duration: TimeInterval,
        chapters: [WatchChapterSummary],
        fileByteCount: Int64,
        sha256: String,
        fileExtension: String,
        transferredAt: Date = .now,
        thumbnailJPEG: Data? = nil,
        resumePosition: TimeInterval = 0,
        lastPlayedAt: Date? = nil
    ) {
        self.bookID = bookID
        self.title = title
        self.author = author
        self.duration = duration
        self.chapters = chapters
        self.fileByteCount = fileByteCount
        self.sha256 = sha256
        self.fileExtension = fileExtension
        self.transferredAt = transferredAt
        self.thumbnailJPEG = thumbnailJPEG
        self.resumePosition = resumePosition
        self.lastPlayedAt = lastPlayedAt
    }

    /// Manifest prepared for WatchConnectivity wire transfer (thumbnail omitted to stay under payload limits).
    public func wireTransferCopy() -> WatchTransferManifest {
        WatchTransferManifest(
            bookID: bookID,
            title: title,
            author: author,
            duration: duration,
            chapters: chapters,
            fileByteCount: fileByteCount,
            sha256: sha256,
            fileExtension: fileExtension,
            transferredAt: transferredAt,
            thumbnailJPEG: nil,
            resumePosition: resumePosition,
            lastPlayedAt: lastPlayedAt
        )
    }
}

public enum WatchTransferPhase: String, Codable, Sendable, Equatable {
    case queued
    case preparing
    case starting
    case waitingForWatch
    case transferring
    case installing
    case complete
    case failed
}

public struct WatchTransferProgress: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID { bookID }
    public let bookID: UUID
    public let phase: WatchTransferPhase
    /// Phase-local progress from 0…1 when known (`preparing` / `transferring`).
    public let fractionCompleted: Double?
    public let statusDetail: String?
    public let errorMessage: String?

    public init(
        bookID: UUID,
        phase: WatchTransferPhase,
        fractionCompleted: Double? = nil,
        statusDetail: String? = nil,
        errorMessage: String? = nil
    ) {
        self.bookID = bookID
        self.phase = phase
        self.fractionCompleted = fractionCompleted
        self.statusDetail = statusDetail
        self.errorMessage = errorMessage
    }

    /// Combined 0…100 progress across prepare → send → install.
    public var overallPercent: Int {
        Int((overallFraction * 100).rounded())
    }

    public var overallFraction: Double {
        let unit = min(max(fractionCompleted ?? 0, 0), 1)
        switch phase {
        case .queued: return 0
        case .preparing: return unit * 0.08
        case .starting: return 0.06
        case .waitingForWatch: return 0.08
        case .transferring: return 0.08 + unit * 0.87
        case .installing: return 0.95
        case .complete: return 1
        case .failed: return unit
        }
    }

    public var displayLabel: String {
        if let statusDetail, !statusDetail.isEmpty { return statusDetail }
        switch phase {
        case .queued: return "Queued…"
        case .preparing: return "Preparing…"
        case .starting: return "Starting transfer…"
        case .waitingForWatch: return "Waiting for Watch to accept…"
        case .transferring: return "Sending to Watch…"
        case .installing: return "Installing on Watch…"
        case .complete: return "Complete"
        case .failed: return errorMessage ?? "Transfer failed."
        }
    }
}

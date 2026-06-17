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
}

public enum WatchTransferPhase: String, Codable, Sendable, Equatable {
    case queued
    case transferring
    case complete
    case failed
}

public struct WatchTransferProgress: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID { bookID }
    public let bookID: UUID
    public let phase: WatchTransferPhase
    public let errorMessage: String?

    public init(bookID: UUID, phase: WatchTransferPhase, errorMessage: String? = nil) {
        self.bookID = bookID
        self.phase = phase
        self.errorMessage = errorMessage
    }
}

//
//  WatchLocalLibraryStoring.swift
//  AudiopigWatch
//

import Foundation

enum WatchLocalLibraryError: LocalizedError {
    case invalidManifest
    case checksumMismatch
    case storageFull
    case bookNotFound
    case ingestFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidManifest: return "Invalid transfer manifest."
        case .checksumMismatch: return "Transferred file failed integrity check."
        case .storageFull: return "Watch storage is full."
        case .bookNotFound: return "Book not found on Watch."
        case .ingestFailed(let message): return message
        }
    }
}

/// On-device transferred audiobooks on Apple Watch.
@MainActor
protocol WatchLocalLibraryStoring: AnyObject {
    var budgetBytes: Int64 { get }

    func allBooks() -> [WatchBookSummary]
    func allManifests() -> [WatchTransferManifest]
    func manifest(for bookID: UUID) -> WatchTransferManifest?
    func localURL(for bookID: UUID) -> URL?
    func usedBytes() -> Int64
    func localBooksPayload() -> WatchLocalBooksPayload
    func ingest(transferredFile: URL, manifest: WatchTransferManifest) throws -> WatchTransferManifest
    func remove(bookID: UUID) throws
    func updateResumePosition(bookID: UUID, time: TimeInterval) throws
    func updateLastPlayed(bookID: UUID) throws
}

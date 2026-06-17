//
//  WatchTransferServiceProtocol.swift
//  Audiopig
//

import Foundation

@MainActor
protocol WatchTransferServiceProtocol: AnyObject {
    var progressByBookID: [UUID: WatchTransferProgress] { get }
    var localBooks: WatchLocalBooksPayload? { get }
    /// Bumps whenever transfer progress or watch library state changes (drives SwiftUI refresh).
    var stateRevision: UInt64 { get }
    var onStateChanged: (@MainActor () -> Void)? { get set }

    func transfer(audiobook: Audiobook) async
    func transfer(audiobooks: [Audiobook]) async
    func cancelTransfer(bookID: UUID)
    func removeFromWatch(bookID: UUID) async
    func isOnWatch(bookID: UUID) -> Bool
    func isTransferring(bookID: UUID) -> Bool
    func transferProgress(for bookID: UUID) -> WatchTransferProgress?
    func transferFailureMessage(for bookID: UUID) -> String?
    func refreshWatchLibraryState() async
    func handleLocalBooksAcknowledgement(_ payload: WatchLocalBooksPayload)
    func handleTransferFailure(bookID: UUID, errorMessage: String)
    func handleFileDelivered(bookID: UUID)
}

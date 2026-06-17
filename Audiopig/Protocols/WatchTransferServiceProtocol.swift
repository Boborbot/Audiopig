//
//  WatchTransferServiceProtocol.swift
//  Audiopig
//

import Foundation

@MainActor
protocol WatchTransferServiceProtocol: AnyObject {
    var progressByBookID: [UUID: WatchTransferProgress] { get }
    var localBooks: WatchLocalBooksPayload? { get }

    func transfer(audiobook: Audiobook) async
    func transfer(audiobooks: [Audiobook]) async
    func removeFromWatch(bookID: UUID) async
    func isOnWatch(bookID: UUID) -> Bool
    func isTransferring(bookID: UUID) -> Bool
    func handleLocalBooksAcknowledgement(_ payload: WatchLocalBooksPayload)
}

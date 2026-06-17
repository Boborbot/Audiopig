//
//  WatchConnectivityBridgeProtocol.swift
//  Audiopig
//

import Foundation

/// iPhone-side bridge to the paired Apple Watch. All WatchConnectivity types stay in the concrete service.
@MainActor
protocol WatchConnectivityBridgeProtocol: AnyObject {
    var isPaired: Bool { get }
    var isWatchAppInstalled: Bool { get }
    var isReachable: Bool { get }
    var isSessionActivated: Bool { get }
    var latestLocalBooks: WatchLocalBooksPayload? { get }

    func activate()
    func ensureSessionActivated(timeout: TimeInterval) async -> Bool
    func publishSnapshot(_ snapshot: WatchPlaybackSnapshot, includeArtwork: Bool)
    func publishChapters(_ payload: WatchChaptersPayload)
    func publishRecentBooks(_ payload: WatchRecentBooksPayload)
    func publishLocalBooks(_ payload: WatchLocalBooksPayload)
    func restoreLocalBooksCache(_ payload: WatchLocalBooksPayload)
    func publishSettings(_ settings: WatchSettingsSnapshot)
    @discardableResult
    func transferBook(manifest: WatchTransferManifest, fileURL: URL) async -> Bool
    func cancelTransfer(bookID: UUID)
    func sendCommandToWatch(_ command: WatchCommand) async -> WatchCommandResult

    /// Handles inbound commands from the Watch. Set once during app bootstrap.
    var commandHandler: (@MainActor (WatchCommand) async -> WatchCommandResult)? { get set }
    var transferCompletionHandler: (@MainActor (UUID, Bool, String?) -> Void)? { get set }
    /// Called when `WCSession.transferFile` finishes without error (file reached the Watch app).
    var fileDeliveredHandler: (@MainActor (UUID) -> Void)? { get set }
    /// Outbound file bytes sent so far (0…1) while `WCSession.transferFile` is in flight.
    var fileProgressHandler: (@MainActor (UUID, Double) -> Void)? { get set }
    /// Called when Watch reachability changes after session activation.
    var reachabilityHandler: (@MainActor (Bool) -> Void)? { get set }
}

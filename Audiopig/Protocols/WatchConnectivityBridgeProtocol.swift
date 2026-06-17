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
    var latestLocalBooks: WatchLocalBooksPayload? { get }

    func activate()
    func publishSnapshot(_ snapshot: WatchPlaybackSnapshot, includeArtwork: Bool)
    func publishChapters(_ payload: WatchChaptersPayload)
    func publishRecentBooks(_ payload: WatchRecentBooksPayload)
    func publishLocalBooks(_ payload: WatchLocalBooksPayload)
    func publishSettings(_ settings: WatchSettingsSnapshot)
    func transferBook(manifest: WatchTransferManifest, fileURL: URL)
    func sendCommandToWatch(_ command: WatchCommand) async -> WatchCommandResult

    /// Handles inbound commands from the Watch. Set once during app bootstrap.
    var commandHandler: (@MainActor (WatchCommand) async -> WatchCommandResult)? { get set }
    var transferCompletionHandler: (@MainActor (UUID, Bool, String?) -> Void)? { get set }
}

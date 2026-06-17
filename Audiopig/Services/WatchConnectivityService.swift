//
//  WatchConnectivityService.swift
//  Audiopig
//

import Foundation
import WatchConnectivity

@MainActor
final class WatchConnectivityService: NSObject, WatchConnectivityBridgeProtocol {
    private let session: WCSession
    private var lastSnapshot: WatchPlaybackSnapshot?
    private var lastArtworkBookID: UUID?
    private var outboundContext: [String: Any] = [:]
    private var pendingTransfers: [UUID: WatchTransferManifest] = [:]
    private var pendingTransferURLs: [UUID: URL] = [:]
    private var transferRetryCount: [UUID: Int] = [:]

    var commandHandler: (@MainActor (WatchCommand) async -> WatchCommandResult)?
    var transferCompletionHandler: (@MainActor (UUID, Bool, String?) -> Void)?
    private(set) var latestLocalBooks: WatchLocalBooksPayload?

    var isPaired: Bool { session.isPaired }
    var isWatchAppInstalled: Bool { session.isWatchAppInstalled }
    var isReachable: Bool { session.isReachable }

    override init() {
        self.session = WCSession.default
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func publishSnapshot(_ snapshot: WatchPlaybackSnapshot, includeArtwork: Bool) {
        lastSnapshot = snapshot

        var toSend = snapshot
        if includeArtwork, snapshot.artworkJPEG != nil, let bookID = snapshot.bookID {
            lastArtworkBookID = bookID
        } else if snapshot.bookID == lastArtworkBookID {
            toSend = WatchPlaybackSnapshot(
                revision: snapshot.revision,
                bookID: snapshot.bookID,
                title: snapshot.title,
                author: snapshot.author,
                chapterTitle: snapshot.chapterTitle,
                playbackState: snapshot.playbackState,
                playbackSpeed: snapshot.playbackSpeed,
                skipForwardSeconds: snapshot.skipForwardSeconds,
                skipBackwardSeconds: snapshot.skipBackwardSeconds,
                chapterIndex: snapshot.chapterIndex,
                chapterCount: snapshot.chapterCount,
                chapterElapsed: snapshot.chapterElapsed,
                chapterDuration: snapshot.chapterDuration,
                chapterProgress: snapshot.chapterProgress,
                globalCurrentTime: snapshot.globalCurrentTime,
                globalDuration: snapshot.globalDuration,
                systemVolume: snapshot.systemVolume,
                source: snapshot.source,
                artworkJPEG: nil,
                updatedAt: snapshot.updatedAt
            )
        }

        pushToContext(key: WatchMessageKeys.snapshot, encodable: toSend)
    }

    func publishChapters(_ payload: WatchChaptersPayload) {
        pushToContext(key: WatchMessageKeys.chapters, encodable: payload)
    }

    func publishRecentBooks(_ payload: WatchRecentBooksPayload) {
        pushToContext(key: WatchMessageKeys.recentBooks, encodable: payload)
    }

    func publishLocalBooks(_ payload: WatchLocalBooksPayload) {
        latestLocalBooks = payload
        pushToContext(key: WatchMessageKeys.localBooks, encodable: payload)
    }

    func publishSettings(_ settings: WatchSettingsSnapshot) {
        pushToContext(key: WatchMessageKeys.settings, encodable: settings)
    }

    func transferBook(manifest: WatchTransferManifest, fileURL: URL) {
        guard session.activationState == .activated else { return }
        pendingTransfers[manifest.bookID] = manifest
        pendingTransferURLs[manifest.bookID] = fileURL
        guard let manifestData = try? WatchMessageCodec.encode(manifest) else { return }
        let metadata: [String: Any] = [
            WatchMessageKeys.transferBookID: manifest.bookID.uuidString,
            WatchMessageKeys.transferManifest: manifestData
        ]
        session.transferFile(fileURL, metadata: metadata)
    }

    func sendCommandToWatch(_ command: WatchCommand) async -> WatchCommandResult {
        guard session.activationState == .activated else {
            return .failure("Watch is not available.")
        }

        let payload: [String: Any]
        do {
            payload = [WatchMessageKeys.command: try WatchMessageCodec.encode(command)]
        } catch {
            return .failure("Could not encode command.")
        }

        guard session.isReachable else {
            return .failure("Open Audiopig on Apple Watch.")
        }

        return await withCheckedContinuation { continuation in
            session.sendMessage(payload, replyHandler: { reply in
                Task { @MainActor in
                    if let data = reply[WatchMessageKeys.commandResult] as? Data,
                       let result = try? WatchMessageCodec.decode(WatchCommandResult.self, from: data) {
                        continuation.resume(returning: result)
                    } else {
                        continuation.resume(returning: .ok())
                    }
                }
            }, errorHandler: { _ in
                Task { @MainActor in
                    continuation.resume(returning: .failure("Could not reach Apple Watch."))
                }
            })
        }
    }

    private func pushToContext<T: Encodable>(key: String, encodable: T) {
        guard session.activationState == .activated else { return }
        do {
            outboundContext[key] = try WatchMessageCodec.encode(encodable)
            try session.updateApplicationContext(outboundContext)
        } catch {
            // Best-effort sync.
        }
    }

    private func handleCommand(_ command: WatchCommand) async -> WatchCommandResult {
        guard let commandHandler else {
            return .failure("Phone app is not ready.")
        }
        return await commandHandler(command)
    }

    private func decodeCommand(from message: [String: Any]) -> WatchCommand? {
        guard let data = message[WatchMessageKeys.command] as? Data else { return nil }
        return try? WatchMessageCodec.decode(WatchCommand.self, from: data)
    }

    private func reply(
        result: WatchCommandResult,
        replyHandler: (([String: Any]) -> Void)?
    ) {
        guard let replyHandler else { return }
        do {
            let data = try WatchMessageCodec.encode(result)
            replyHandler([WatchMessageKeys.commandResult: data])
        } catch {
            replyHandler([:])
        }
    }

    private func completeTransfer(bookID: UUID, success: Bool, errorMessage: String?) {
        pendingTransfers.removeValue(forKey: bookID)
        pendingTransferURLs.removeValue(forKey: bookID)
        transferRetryCount.removeValue(forKey: bookID)
        transferCompletionHandler?(bookID, success, errorMessage)
    }

    private func retryTransferIfNeeded(bookID: UUID) {
        guard let manifest = pendingTransfers[bookID],
              let fileURL = pendingTransferURLs[bookID] else { return }
        let retries = transferRetryCount[bookID, default: 0]
        guard retries < 2 else {
            completeTransfer(bookID: bookID, success: false, errorMessage: "Transfer failed after retries.")
            return
        }
        transferRetryCount[bookID] = retries + 1
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            completeTransfer(bookID: bookID, success: false, errorMessage: "Source file missing.")
            return
        }
        transferBook(manifest: manifest, fileURL: fileURL)
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            if let snapshot = lastSnapshot {
                publishSnapshot(snapshot, includeArtwork: true)
            }
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {}

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            guard let command = decodeCommand(from: message) else { return }
            let result = await handleCommand(command)
            if case .requestSnapshot = command, let snapshot = result.snapshot ?? lastSnapshot {
                publishSnapshot(snapshot, includeArtwork: false)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            guard let command = decodeCommand(from: message) else {
                replyHandler([:])
                return
            }
            let result = await handleCommand(command)
            reply(result: result, replyHandler: replyHandler)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            guard let command = decodeCommand(from: userInfo) else { return }
            _ = await handleCommand(command)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        Task { @MainActor in
            guard let manifestData = fileTransfer.file.metadata?[WatchMessageKeys.transferManifest] as? Data,
                  let manifest = try? WatchMessageCodec.decode(WatchTransferManifest.self, from: manifestData) else {
                return
            }

            if error != nil {
                retryTransferIfNeeded(bookID: manifest.bookID)
            }
        }
    }
}

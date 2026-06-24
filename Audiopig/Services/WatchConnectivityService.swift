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
    private var lastChapters: WatchChaptersPayload?
    private var lastRecentBooks: WatchRecentBooksPayload?
    private var lastSettings: WatchSettingsSnapshot?
    private var lastArtworkBookID: UUID?
    private var outboundContext: [String: Any] = [:]
    private var pendingTransfers: [UUID: WatchTransferManifest] = [:]
    private var pendingTransferURLs: [UUID: URL] = [:]
    private var transferRetryCount: [UUID: Int] = [:]
    private var activeFileTransfers: [UUID: WCSessionFileTransfer] = [:]
    private var cancelledBookIDs: Set<UUID> = []

    var commandHandler: (@MainActor (WatchCommand) async -> WatchCommandResult)?
    var transferCompletionHandler: (@MainActor (UUID, Bool, String?) -> Void)?
    var fileDeliveredHandler: (@MainActor (UUID) -> Void)?
    var fileProgressHandler: (@MainActor (UUID, Double) -> Void)?
    var reachabilityHandler: (@MainActor (Bool) -> Void)?
    private(set) var latestLocalBooks: WatchLocalBooksPayload?
    private var fileProgressObservations: [UUID: NSKeyValueObservation] = [:]
    private var fileProgressPollTasks: [UUID: Task<Void, Never>] = [:]

    var isPaired: Bool { session.isPaired }
    var isWatchAppInstalled: Bool { session.isWatchAppInstalled }
    var isReachable: Bool { session.isReachable }
    var isSessionActivated: Bool { session.activationState == .activated }

    override init() {
        self.session = WCSession.default
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        session.delegate = self
        session.activate()
    }

    func ensureSessionActivated(timeout: TimeInterval = 8) async -> Bool {
        if session.activationState == .activated { return true }
        let deadline = Date().addingTimeInterval(timeout)
        while session.activationState != .activated {
            if Date() >= deadline { return false }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return true
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
                playbackTimelineScope: snapshot.playbackTimelineScope,
                systemVolume: snapshot.systemVolume,
                source: snapshot.source,
                artworkJPEG: nil,
                updatedAt: snapshot.updatedAt
            )
        }

        pushToContext(key: WatchMessageKeys.snapshot, encodable: toSend)
    }

    func publishChapters(_ payload: WatchChaptersPayload) {
        lastChapters = payload
        pushToContext(key: WatchMessageKeys.chapters, encodable: payload)
    }

    func publishRecentBooks(_ payload: WatchRecentBooksPayload) {
        lastRecentBooks = payload
        pushToContext(key: WatchMessageKeys.recentBooks, encodable: payload)
    }

    func publishLocalBooks(_ payload: WatchLocalBooksPayload) {
        latestLocalBooks = payload
        WatchLocalBooksCache.save(payload)
        pushToContext(key: WatchMessageKeys.localBooks, encodable: payload)
    }

    func restoreLocalBooksCache(_ payload: WatchLocalBooksPayload) {
        latestLocalBooks = payload
    }

    func publishSettings(_ settings: WatchSettingsSnapshot) {
        lastSettings = settings
        pushToContext(key: WatchMessageKeys.settings, encodable: settings)
    }

    @discardableResult
    func transferBook(manifest: WatchTransferManifest, fileURL: URL) async -> Bool {
        guard WatchFeatures.localPlaybackEnabled else { return false }
        guard await ensureSessionActivated() else { return false }
        guard session.isPaired, session.isWatchAppInstalled else { return false }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return false }

        let wireManifest = manifest.wireTransferCopy()
        guard let manifestData = try? WatchMessageCodec.encode(wireManifest) else { return false }

        let stagedURL: URL
        do {
            stagedURL = try WatchTransferStaging.stageOutgoingFile(
                bookID: manifest.bookID,
                sourceURL: fileURL,
                fileExtension: manifest.fileExtension
            )
        } catch {
            return false
        }

        pendingTransfers[manifest.bookID] = manifest
        pendingTransferURLs[manifest.bookID] = stagedURL

        for outstanding in session.outstandingFileTransfers {
            guard let idString = outstanding.file.metadata?[WatchMessageKeys.transferBookID] as? String,
                  let outstandingID = UUID(uuidString: idString),
                  outstandingID == manifest.bookID else { continue }
            outstanding.cancel()
            stopObservingFileTransferProgress(for: manifest.bookID)
        }

        // Deliver manifest before the file; also embed slim manifest on the file itself as a fallback.
        session.transferUserInfo([
            WatchMessageKeys.transferBookID: manifest.bookID.uuidString,
            WatchMessageKeys.transferManifest: manifestData
        ])

        let fileMetadata: [String: Any] = [
            WatchMessageKeys.transferBookID: manifest.bookID.uuidString,
            WatchMessageKeys.transferManifest: manifestData
        ]
        let transfer = session.transferFile(stagedURL, metadata: fileMetadata)
        activeFileTransfers[manifest.bookID] = transfer
        observeFileTransferProgress(for: manifest.bookID, transfer: transfer)
        return true
    }

    func cancelTransfer(bookID: UUID) {
        cancelledBookIDs.insert(bookID)
        activeFileTransfers[bookID]?.cancel()
        activeFileTransfers.removeValue(forKey: bookID)
        stopObservingFileTransferProgress(for: bookID)
        pendingTransfers.removeValue(forKey: bookID)
        pendingTransferURLs.removeValue(forKey: bookID)
        transferRetryCount.removeValue(forKey: bookID)
        WatchTransferStaging.removeOutgoingStage(bookID: bookID)
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
            if case .requestLocalBooks = command {
                session.transferUserInfo(payload)
                return .ok()
            }
            return .failure("Open \(Brand.displayName) on Apple Watch.")
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
            }, errorHandler: { [session] _ in
                Task { @MainActor in
                    if case .requestLocalBooks = command {
                        session.transferUserInfo(payload)
                        continuation.resume(returning: .ok())
                    } else {
                        continuation.resume(returning: .failure("Could not reach Apple Watch."))
                    }
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
        activeFileTransfers.removeValue(forKey: bookID)
        stopObservingFileTransferProgress(for: bookID)
        pendingTransfers.removeValue(forKey: bookID)
        pendingTransferURLs.removeValue(forKey: bookID)
        transferRetryCount.removeValue(forKey: bookID)
        WatchTransferStaging.removeOutgoingStage(bookID: bookID)
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
        Task {
            _ = await transferBook(manifest: manifest, fileURL: fileURL)
        }
    }

    private func bookID(from metadata: [String: Any]?) -> UUID? {
        guard let idString = metadata?[WatchMessageKeys.transferBookID] as? String else { return nil }
        return UUID(uuidString: idString)
    }

    private func observeFileTransferProgress(for bookID: UUID, transfer: WCSessionFileTransfer) {
        stopObservingFileTransferProgress(for: bookID)
        fileProgressObservations[bookID] = transfer.progress.observe(\.fractionCompleted, options: [.initial, .new]) { [weak self] progress, _ in
            let fraction = progress.fractionCompleted
            Task { @MainActor in
                self?.fileProgressHandler?(bookID, fraction)
            }
        }
        startProgressPolling(for: bookID, transfer: transfer)
    }

    private func startProgressPolling(for bookID: UUID, transfer: WCSessionFileTransfer) {
        fileProgressPollTasks[bookID]?.cancel()
        fileProgressPollTasks[bookID] = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                let fraction = transfer.progress.fractionCompleted
                self?.fileProgressHandler?(bookID, fraction)
            }
        }
    }

    private func stopObservingFileTransferProgress(for bookID: UUID) {
        fileProgressObservations[bookID]?.invalidate()
        fileProgressObservations.removeValue(forKey: bookID)
        fileProgressPollTasks[bookID]?.cancel()
        fileProgressPollTasks.removeValue(forKey: bookID)
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
            republishCachedWatchContext(includeArtwork: true)
            reachabilityHandler?(session.isReachable)
        }
    }

    private func republishCachedWatchContext(includeArtwork: Bool) {
        if let settings = lastSettings {
            publishSettings(settings)
        }
        if let recentBooks = lastRecentBooks {
            publishRecentBooks(recentBooks)
        }
        if let chapters = lastChapters {
            publishChapters(chapters)
        }
        if let snapshot = lastSnapshot {
            publishSnapshot(snapshot, includeArtwork: includeArtwork)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            reachabilityHandler?(session.isReachable)
        }
    }

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
            let bookID = bookID(from: fileTransfer.file.metadata)
                ?? activeFileTransfers.first(where: { $0.value === fileTransfer })?.key
            guard let bookID else { return }

            activeFileTransfers.removeValue(forKey: bookID)
            stopObservingFileTransferProgress(for: bookID)

            if cancelledBookIDs.contains(bookID) {
                cancelledBookIDs.remove(bookID)
                WatchTransferStaging.removeOutgoingStage(bookID: bookID)
                return
            }

            if error != nil {
                retryTransferIfNeeded(bookID: bookID)
            } else {
                WatchTransferStaging.removeOutgoingStage(bookID: bookID)
                fileDeliveredHandler?(bookID)
            }
        }
    }
}

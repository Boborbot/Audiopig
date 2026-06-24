//
//  WatchConnectivityClient.swift
//  AudiopigWatch
//

import Foundation
import WatchConnectivity

enum WatchConnectionState: Equatable {
    case activating
    case companionNotInstalled
    case notReachable
    case reachable
}

@MainActor
final class WatchConnectivityClient: NSObject {
    private let session = WCSession.default
    private var snapshotHandler: ((WatchPlaybackSnapshot) -> Void)?
    private var recentBooksHandler: ((WatchRecentBooksPayload) -> Void)?
    private var localBooksHandler: ((WatchLocalBooksPayload) -> Void)?
    private var chaptersHandler: ((WatchChaptersPayload) -> Void)?
    private var settingsHandler: ((WatchSettingsSnapshot) -> Void)?
    private var connectionStateHandler: ((WatchConnectionState) -> Void)?

    private weak var localStore: WatchLocalLibraryStore?
    private weak var localCoordinator: LocalWatchPlaybackCoordinator?
    private var pendingTransferManifests: [UUID: WatchTransferManifest] = [:]
    private var acceptsTransfers = false

    private(set) var latestSnapshot: WatchPlaybackSnapshot?
    private(set) var latestRecentBooks: WatchRecentBooksPayload?
    private(set) var latestLocalBooks: WatchLocalBooksPayload?
    private(set) var latestChapters: WatchChaptersPayload?
    private(set) var latestSettings: WatchSettingsSnapshot?
    private(set) var isReachable = false
    private(set) var connectionState: WatchConnectionState = .activating

    override init() {
        super.init()
    }

    func configure(
        localStore: WatchLocalLibraryStore,
        localCoordinator: LocalWatchPlaybackCoordinator,
        acceptsTransfers: Bool = WatchFeatures.localPlaybackEnabled
    ) {
        self.localStore = localStore
        self.localCoordinator = localCoordinator
        self.acceptsTransfers = acceptsTransfers
    }

    func activate() {
        guard WCSession.isSupported() else {
            connectionState = .companionNotInstalled
            return
        }
        session.delegate = self
        session.activate()
    }

    func setSnapshotHandler(_ handler: @escaping (WatchPlaybackSnapshot) -> Void) {
        snapshotHandler = handler
        if let latestSnapshot {
            handler(latestSnapshot)
        }
    }

    func setRecentBooksHandler(_ handler: @escaping (WatchRecentBooksPayload) -> Void) {
        recentBooksHandler = handler
        if let latestRecentBooks {
            handler(latestRecentBooks)
        }
    }

    func setLocalBooksHandler(_ handler: @escaping (WatchLocalBooksPayload) -> Void) {
        localBooksHandler = handler
        if let latestLocalBooks {
            handler(latestLocalBooks)
        } else if let localStore {
            let payload = localStore.localBooksPayload()
            latestLocalBooks = payload
            handler(payload)
        }
    }

    func setChaptersHandler(_ handler: @escaping (WatchChaptersPayload) -> Void) {
        chaptersHandler = handler
        if let latestChapters {
            handler(latestChapters)
        }
    }

    func setSettingsHandler(_ handler: @escaping (WatchSettingsSnapshot) -> Void) {
        settingsHandler = handler
        if let latestSettings {
            handler(latestSettings)
        }
    }

    func setConnectionStateHandler(_ handler: @escaping (WatchConnectionState) -> Void) {
        connectionStateHandler = handler
        handler(connectionState)
    }

    func send(_ command: WatchCommand) async -> WatchCommandResult {
        await deliverCommandToPhone(command)
    }

    func publishLocalBooksToPhone() async {
        guard acceptsTransfers, let localStore else { return }
        let payload = localStore.localBooksPayload()
        latestLocalBooks = payload
        localBooksHandler?(payload)
        let syncPayload = payload.slimSyncCopy()
        _ = await deliverCommandToPhone(.acknowledgeLocalBooks(syncPayload))
    }

    var connectionErrorMessage: String {
        switch connectionState {
        case .companionNotInstalled:
            return "Install \(Brand.displayName) on iPhone"
        case .notReachable:
            return "Open \(Brand.displayName) on iPhone"
        case .activating:
            return "Connecting to iPhone…"
        case .reachable:
            return "Open \(Brand.displayName) on iPhone"
        }
    }

    private func applySnapshot(_ snapshot: WatchPlaybackSnapshot) {
        latestSnapshot = snapshot
        snapshotHandler?(snapshot)
    }

    private func applyRecentBooks(_ payload: WatchRecentBooksPayload) {
        latestRecentBooks = payload
        recentBooksHandler?(payload)
    }

    private func deliverCommandToPhone(_ command: WatchCommand) async -> WatchCommandResult {
        guard session.activationState == .activated else {
            return .failure(connectionErrorMessage)
        }

        let payload: [String: Any]
        do {
            payload = [WatchMessageKeys.command: try WatchMessageCodec.encode(command)]
        } catch {
            return .failure("Could not encode command.")
        }

        let isTransferStatusCommand: Bool = switch command {
        case .acknowledgeLocalBooks, .reportTransferIngestFailed:
            true
        default:
            false
        }

        if isTransferStatusCommand {
            session.transferUserInfo(payload)
            return .ok(snapshot: latestSnapshot)
        }

        if session.isReachable {
            return await withCheckedContinuation { continuation in
                session.sendMessage(payload, replyHandler: { reply in
                    Task { @MainActor in
                        if let data = reply[WatchMessageKeys.commandResult] as? Data,
                           let result = try? WatchMessageCodec.decode(WatchCommandResult.self, from: data) {
                            if let snapshot = result.snapshot {
                                self.applySnapshot(snapshot)
                            }
                            if let recentBooks = result.recentBooks {
                                self.applyRecentBooks(recentBooks)
                            }
                            continuation.resume(returning: result)
                        } else {
                            continuation.resume(returning: .failure("No response from iPhone"))
                        }
                    }
                }, errorHandler: { [session] _ in
                    Task { @MainActor in
                        session.transferUserInfo(payload)
                        continuation.resume(returning: .ok(snapshot: self.latestSnapshot))
                    }
                })
            }
        }

        session.transferUserInfo(payload)
        return .ok(snapshot: latestSnapshot)
    }

    private func ingestContext(_ context: [String: Any]) {
        if let data = context[WatchMessageKeys.snapshot] as? Data,
           let snapshot = try? WatchMessageCodec.decode(WatchPlaybackSnapshot.self, from: data) {
            applySnapshot(snapshot)
        }

        if let data = context[WatchMessageKeys.recentBooks] as? Data,
           let payload = try? WatchMessageCodec.decode(WatchRecentBooksPayload.self, from: data) {
            applyRecentBooks(payload)
        }

        if let data = context[WatchMessageKeys.localBooks] as? Data,
           let payload = try? WatchMessageCodec.decode(WatchLocalBooksPayload.self, from: data) {
            latestLocalBooks = payload
            localBooksHandler?(payload)
        }

        if let data = context[WatchMessageKeys.chapters] as? Data,
           let payload = try? WatchMessageCodec.decode(WatchChaptersPayload.self, from: data) {
            latestChapters = payload
            chaptersHandler?(payload)
        }

        if let data = context[WatchMessageKeys.settings] as? Data,
           let settings = try? WatchMessageCodec.decode(WatchSettingsSnapshot.self, from: data) {
            latestSettings = settings
            settingsHandler?(settings)
        }
    }

    private func refreshConnectionState() {
        guard session.activationState == .activated else {
            connectionState = .activating
            isReachable = false
            return
        }

        guard session.isCompanionAppInstalled else {
            connectionState = .companionNotInstalled
            isReachable = false
            return
        }

        isReachable = session.isReachable
        connectionState = session.isReachable ? .reachable : .notReachable
        connectionStateHandler?(connectionState)
    }

    private func handleIncomingFile(at fileURL: URL, metadata: [String: Any]?) async {
        defer { try? FileManager.default.removeItem(at: fileURL) }

        guard acceptsTransfers else { return }
        guard let localStore else {
            reportIngestFailureIfPossible(metadata: metadata, message: "Watch library is not ready.")
            return
        }

        guard let manifest = await resolveManifest(for: metadata) else {
            reportIngestFailureIfPossible(metadata: metadata, message: "Could not read transfer metadata.")
            return
        }

        pendingTransferManifests.removeValue(forKey: manifest.bookID)

        do {
            _ = try localStore.ingest(transferredFile: fileURL, manifest: manifest)
            await publishLocalBooksToPhone()
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            _ = await deliverCommandToPhone(
                .reportTransferIngestFailed(bookID: manifest.bookID, errorMessage: message)
            )
        }
    }

    private func resolveManifest(for metadata: [String: Any]?) async -> WatchTransferManifest? {
        for _ in 0..<24 {
            if let manifest = resolveManifestSynchronously(for: metadata) {
                return manifest
            }
            try? await Task.sleep(for: .milliseconds(250))
        }
        return resolveManifestSynchronously(for: metadata)
    }

    private func resolveManifestSynchronously(for metadata: [String: Any]?) -> WatchTransferManifest? {
        if let bookIDString = metadata?[WatchMessageKeys.transferBookID] as? String,
           let bookID = UUID(uuidString: bookIDString),
           let manifest = pendingTransferManifests[bookID] {
            return manifest
        }

        if let manifestData = metadata?[WatchMessageKeys.transferManifest] as? Data,
           let manifest = try? WatchMessageCodec.decode(WatchTransferManifest.self, from: manifestData) {
            return manifest
        }

        return nil
    }

    private func ingestTransferManifestPayload(_ payload: [String: Any]) {
        guard acceptsTransfers else { return }
        guard let bookIDString = payload[WatchMessageKeys.transferBookID] as? String,
              let bookID = UUID(uuidString: bookIDString),
              let manifestData = payload[WatchMessageKeys.transferManifest] as? Data,
              let manifest = try? WatchMessageCodec.decode(WatchTransferManifest.self, from: manifestData) else {
            return
        }
        pendingTransferManifests[bookID] = manifest
    }

    private func reportIngestFailureIfPossible(metadata: [String: Any]?, message: String) {
        guard let bookIDString = metadata?[WatchMessageKeys.transferBookID] as? String,
              let bookID = UUID(uuidString: bookIDString) else { return }
        Task {
            _ = await deliverCommandToPhone(
                .reportTransferIngestFailed(bookID: bookID, errorMessage: message)
            )
        }
    }
}

extension WatchConnectivityClient: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            refreshConnectionState()
            ingestContext(session.receivedApplicationContext)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            let wasReachable = isReachable
            refreshConnectionState()
            if !wasReachable, isReachable {
                await publishLocalBooksToPhone()
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            ingestContext(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        Task { @MainActor in
            ingestTransferManifestPayload(userInfo)
            _ = await handlePhoneMessage(userInfo)
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        let metadata = file.metadata
        let stagedURL: URL?
        do {
            stagedURL = try WatchTransferStaging.copyIncomingFile(from: file.fileURL)
        } catch {
            stagedURL = nil
        }

        Task { @MainActor in
            guard let stagedURL else {
                reportIngestFailureIfPossible(
                    metadata: metadata,
                    message: "Could not save incoming transfer file."
                )
                return
            }
            await handleIncomingFile(at: stagedURL, metadata: metadata)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            await handlePhoneMessage(message)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            let reply = await handlePhoneMessage(message)
            replyHandler(reply)
        }
    }

    @MainActor
    private func handlePhoneMessage(_ message: [String: Any]) async -> [String: Any] {
        guard let data = message[WatchMessageKeys.command] as? Data,
              let command = try? WatchMessageCodec.decode(WatchCommand.self, from: data) else {
            return [:]
        }

        switch command {
        case .deleteLocalBook(let bookID):
            guard acceptsTransfers else {
                return encodeResult(.failure("Watch library is not available."))
            }
            localCoordinator?.unloadIfPlaying(bookID: bookID)
            try? localStore?.remove(bookID: bookID)
            await publishLocalBooksToPhone()
            return encodeResult(.ok())

        case .requestLocalBooks:
            guard acceptsTransfers, let localStore else {
                return encodeResult(.failure("Watch library is not available."))
            }
            let payload = localStore.localBooksPayload().slimSyncCopy()
            latestLocalBooks = payload
            localBooksHandler?(payload)
            await publishLocalBooksToPhone()
            return encodeResult(.ok(localBooks: payload))

        default:
            return [:]
        }
    }

    @MainActor
    private func encodeResult(_ result: WatchCommandResult) -> [String: Any] {
        guard let data = try? WatchMessageCodec.encode(result) else { return [:] }
        return [WatchMessageKeys.commandResult: data]
    }
}

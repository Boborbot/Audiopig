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

    func configure(localStore: WatchLocalLibraryStore, localCoordinator: LocalWatchPlaybackCoordinator) {
        self.localStore = localStore
        self.localCoordinator = localCoordinator
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
        guard session.activationState == .activated else {
            return .failure(connectionErrorMessage)
        }

        let payload: [String: Any]
        do {
            payload = [WatchMessageKeys.command: try WatchMessageCodec.encode(command)]
        } catch {
            return .failure("Could not encode command.")
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
                            continuation.resume(returning: result)
                        } else {
                            continuation.resume(returning: .failure("No response from iPhone."))
                        }
                    }
                }, errorHandler: { _ in
                    Task { @MainActor in
                        continuation.resume(returning: .failure("Could not reach iPhone."))
                    }
                })
            }
        }

        session.transferUserInfo(payload)
        return .ok(snapshot: latestSnapshot)
    }

    func publishLocalBooksToPhone() async {
        guard let localStore else { return }
        let payload = localStore.localBooksPayload()
        latestLocalBooks = payload
        localBooksHandler?(payload)
        guard isReachable else { return }
        _ = await send(.acknowledgeLocalBooks(payload))
    }

    var connectionErrorMessage: String {
        switch connectionState {
        case .companionNotInstalled:
            return "Install Audiopig on iPhone."
        case .notReachable:
            return "Open Audiopig on iPhone."
        case .activating:
            return "Connecting to iPhone…"
        case .reachable:
            return "Not connected to iPhone."
        }
    }

    private func applySnapshot(_ snapshot: WatchPlaybackSnapshot) {
        latestSnapshot = snapshot
        snapshotHandler?(snapshot)
    }

    private func ingestContext(_ context: [String: Any]) {
        if let data = context[WatchMessageKeys.snapshot] as? Data,
           let snapshot = try? WatchMessageCodec.decode(WatchPlaybackSnapshot.self, from: data) {
            applySnapshot(snapshot)
        }

        if let data = context[WatchMessageKeys.recentBooks] as? Data,
           let payload = try? WatchMessageCodec.decode(WatchRecentBooksPayload.self, from: data) {
            latestRecentBooks = payload
            recentBooksHandler?(payload)
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

    private func handleIncomingFile(_ file: WCSessionFile) {
        guard let localStore else { return }

        guard let manifestData = file.metadata?[WatchMessageKeys.transferManifest] as? Data,
              let manifest = try? WatchMessageCodec.decode(WatchTransferManifest.self, from: manifestData) else {
            try? FileManager.default.removeItem(at: file.fileURL)
            return
        }

        do {
            _ = try localStore.ingest(transferredFile: file.fileURL, manifest: manifest)
            Task { await publishLocalBooksToPhone() }
        } catch {
            try? FileManager.default.removeItem(at: file.fileURL)
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

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        Task { @MainActor in
            handleIncomingFile(file)
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
            localCoordinator?.unloadIfPlaying(bookID: bookID)
            try? localStore?.remove(bookID: bookID)
            await publishLocalBooksToPhone()
            return encodeResult(.ok())

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

//
//  WatchTransferService.swift
//  Audiopig
//

import CryptoKit
import Foundation
import UIKit

@MainActor
final class WatchTransferService: WatchTransferServiceProtocol {
    private(set) var progressByBookID: [UUID: WatchTransferProgress] = [:]
    private(set) var stateRevision: UInt64 = 0
    var onStateChanged: (@MainActor () -> Void)?
    var localBooks: WatchLocalBooksPayload? { watchBridge.latestLocalBooks }

    private let watchBridge: any WatchConnectivityBridgeProtocol
    private var transferQueue: [UUID] = []
    private var activeTransferID: UUID?
    private var pendingManifests: [UUID: WatchTransferManifest] = [:]
    private var pendingSourceURLs: [UUID: URL] = [:]
    private var ackTimeoutTasks: [UUID: Task<Void, Never>] = [:]
    private var outboundTimeoutTasks: [UUID: Task<Void, Never>] = [:]
    private var confirmationPollTasks: [UUID: Task<Void, Never>] = [:]
    private var progressWatchdogTasks: [UUID: Task<Void, Never>] = [:]

    private static let ackTimeoutSeconds: UInt64 = 120
    private static let confirmationPollIntervalSeconds: UInt64 = 2
    private static let confirmationPollAttempts = 45

    init(watchBridge: any WatchConnectivityBridgeProtocol) {
        self.watchBridge = watchBridge
        if WatchFeatures.localPlaybackEnabled, let cached = WatchLocalBooksCache.load() {
            watchBridge.restoreLocalBooksCache(cached)
        }
        guard WatchFeatures.localPlaybackEnabled else { return }
        watchBridge.transferCompletionHandler = { [weak self] bookID, success, error in
            self?.handleTransferCompletion(bookID: bookID, success: success, error: error)
        }
        watchBridge.fileDeliveredHandler = { [weak self] bookID in
            self?.handleFileDelivered(bookID: bookID)
        }
        watchBridge.fileProgressHandler = { [weak self] bookID, fraction in
            self?.handleFileProgress(bookID: bookID, fraction: fraction)
        }
    }

    func transfer(audiobook: Audiobook) async {
        await transfer(audiobooks: [audiobook])
    }

    func transfer(audiobooks: [Audiobook]) async {
        guard WatchFeatures.localPlaybackEnabled else { return }
        await refreshWatchLibraryState()
        reconcileStuckTransfers()

        for audiobook in audiobooks {
            if isOnWatch(bookID: audiobook.id) {
                if isTransferring(bookID: audiobook.id) {
                    watchBridge.cancelTransfer(bookID: audiobook.id)
                    handleTransferCompletion(bookID: audiobook.id, success: true, error: nil)
                } else {
                    clearTransferState(for: audiobook.id)
                }
                continue
            }
            guard !isTransferring(bookID: audiobook.id) else { continue }

            if let preflightError = await preflightTransferError() {
                setProgress(
                    bookID: audiobook.id,
                    phase: .failed,
                    errorMessage: preflightError
                )
                continue
            }

            setProgress(bookID: audiobook.id, phase: .queued)

            do {
                setProgress(bookID: audiobook.id, phase: .preparing, fractionCompleted: 0)
                let manifest = try await buildManifest(for: audiobook) { [weak self] fraction in
                    Task { @MainActor in
                        self?.setProgress(
                            bookID: audiobook.id,
                            phase: .preparing,
                            fractionCompleted: fraction
                        )
                    }
                }
                pendingManifests[audiobook.id] = manifest
                pendingSourceURLs[audiobook.id] = audiobook.fileURL
                transferQueue.append(audiobook.id)
            } catch {
                setProgress(
                    bookID: audiobook.id,
                    phase: .failed,
                    errorMessage: error.localizedDescription
                )
            }
        }
        startNextTransferIfNeeded()
    }

    func cancelTransfer(bookID: UUID) {
        transferQueue.removeAll { $0 == bookID }
        pendingManifests.removeValue(forKey: bookID)
        pendingSourceURLs.removeValue(forKey: bookID)
        progressByBookID.removeValue(forKey: bookID)
        cancelAckTimeout(for: bookID)
        cancelOutboundTimeout(for: bookID)
        cancelConfirmationPoll(for: bookID)
        cancelProgressWatchdog(for: bookID)

        if activeTransferID == bookID {
            watchBridge.cancelTransfer(bookID: bookID)
            activeTransferID = nil
            startNextTransferIfNeeded()
        }
        notifyStateChanged()
    }

    func removeFromWatch(bookID: UUID) async {
        _ = await watchBridge.sendCommandToWatch(.deleteLocalBook(bookID: bookID))
        await refreshWatchLibraryState()
    }

    func isOnWatch(bookID: UUID) -> Bool {
        localBooks?.books.contains(where: { $0.id == bookID }) == true
    }

    func isTransferring(bookID: UUID) -> Bool {
        guard let progress = progressByBookID[bookID] else { return false }
        switch progress.phase {
        case .queued, .preparing, .starting, .waitingForWatch, .transferring, .installing:
            return true
        case .complete, .failed:
            return false
        }
    }

    func transferProgress(for bookID: UUID) -> WatchTransferProgress? {
        progressByBookID[bookID]
    }

    func transferFailureMessage(for bookID: UUID) -> String? {
        guard let progress = progressByBookID[bookID], progress.phase == .failed else { return nil }
        return progress.errorMessage
    }

    func refreshWatchLibraryState() async {
        guard WatchFeatures.localPlaybackEnabled else { return }
        _ = await watchBridge.ensureSessionActivated(timeout: 8)

        if !watchBridge.isReachable {
            for _ in 0..<15 {
                try? await Task.sleep(for: .milliseconds(200))
                if watchBridge.isReachable { break }
            }
        }

        let booksBefore = watchBridge.latestLocalBooks?.books.map(\.id) ?? []

        let result = await watchBridge.sendCommandToWatch(.requestLocalBooks)
        if let payload = result.localBooks {
            applyWatchLibrarySnapshot(payload)
            return
        }

        // Watch may answer asynchronously via `acknowledgeLocalBooks` after `transferUserInfo`.
        if result.success {
            for _ in 0..<12 {
                try? await Task.sleep(for: .milliseconds(500))
                if let payload = watchBridge.latestLocalBooks {
                    let ids = payload.books.map(\.id)
                    if ids != booksBefore, !ids.isEmpty || booksBefore.isEmpty {
                        applyWatchLibrarySnapshot(payload)
                        return
                    }
                }
            }
        }

        if let payload = watchBridge.latestLocalBooks ?? WatchLocalBooksCache.load() {
            applyWatchLibrarySnapshot(payload)
        }
    }

    func handleLocalBooksAcknowledgement(_ payload: WatchLocalBooksPayload) {
        applyWatchLibrarySnapshot(payload)
    }

    func handleTransferFailure(bookID: UUID, errorMessage: String) {
        guard pendingManifests[bookID] != nil
            || activeTransferID == bookID
            || isTransferring(bookID: bookID) else { return }
        handleTransferCompletion(bookID: bookID, success: false, error: errorMessage)
    }

    func handleFileDelivered(bookID: UUID) {
        guard pendingManifests[bookID] != nil else { return }
        cancelProgressWatchdog(for: bookID)
        setProgress(bookID: bookID, phase: .installing)
        scheduleAckTimeout(for: bookID)
        startConfirmationPolling(for: bookID)
    }

    #if DEBUG
    func testing_setPendingTransfer(bookID: UUID, manifest: WatchTransferManifest) {
        pendingManifests[bookID] = manifest
        activeTransferID = bookID
        setProgress(bookID: bookID, phase: .transferring, fractionCompleted: 0)
    }
    #endif

    // MARK: - Private

    private func applyWatchLibrarySnapshot(_ payload: WatchLocalBooksPayload) {
        watchBridge.publishLocalBooks(payload)

        for bookID in Array(pendingManifests.keys) where payload.books.contains(where: { $0.id == bookID }) {
            handleTransferCompletion(bookID: bookID, success: true, error: nil)
        }

        for bookID in Array(progressByBookID.keys) where payload.books.contains(where: { $0.id == bookID }) {
            if pendingManifests[bookID] == nil, activeTransferID != bookID {
                clearTransferState(for: bookID)
            }
        }

        for book in payload.books {
            guard let progress = progressByBookID[book.id] else { continue }
            switch progress.phase {
            case .queued, .preparing, .starting, .waitingForWatch, .transferring, .installing:
                if pendingManifests[book.id] == nil, activeTransferID != book.id {
                    progressByBookID.removeValue(forKey: book.id)
                }
            case .complete, .failed:
                break
            }
        }

        notifyStateChanged()
    }

    private func reconcileStuckTransfers() {
        for bookID in Array(progressByBookID.keys) where isOnWatch(bookID: bookID) {
            handleTransferCompletion(bookID: bookID, success: true, error: nil)
        }
    }

    private func clearTransferState(for bookID: UUID) {
        progressByBookID.removeValue(forKey: bookID)
        notifyStateChanged()
    }

    private func handleFileProgress(bookID: UUID, fraction: Double) {
        guard pendingManifests[bookID] != nil else { return }
        let clamped = min(max(fraction, 0), 1)
        if clamped > 0.001 {
            cancelProgressWatchdog(for: bookID)
        }
        let phase: WatchTransferPhase
        if clamped > 0.001 {
            phase = .transferring
        } else if progressByBookID[bookID]?.phase == .waitingForWatch {
            phase = .waitingForWatch
        } else {
            phase = .transferring
        }
        setProgress(bookID: bookID, phase: phase, fractionCompleted: clamped)
    }

    private func setProgress(
        bookID: UUID,
        phase: WatchTransferPhase,
        fractionCompleted: Double? = nil,
        statusDetail: String? = nil,
        errorMessage: String? = nil
    ) {
        progressByBookID[bookID] = WatchTransferProgress(
            bookID: bookID,
            phase: phase,
            fractionCompleted: fractionCompleted,
            statusDetail: statusDetail,
            errorMessage: errorMessage
        )
        notifyStateChanged()
    }

    private func startNextTransferIfNeeded() {
        guard activeTransferID == nil, let bookID = transferQueue.first else { return }
        transferQueue.removeFirst()
        guard let manifest = pendingManifests[bookID],
              let sourceURL = pendingSourceURLs[bookID] else { return }

        activeTransferID = bookID
        setProgress(bookID: bookID, phase: .starting)

        Task {
            let started = await watchBridge.transferBook(manifest: manifest, fileURL: sourceURL)
            guard started else {
                handleTransferCompletion(
                    bookID: bookID,
                    success: false,
                    error: watchUnavailableMessage()
                )
                return
            }
            setProgress(bookID: bookID, phase: .transferring, fractionCompleted: 0)
            scheduleOutboundTimeout(for: bookID, fileByteCount: manifest.fileByteCount)
            startConfirmationPolling(for: bookID)
            startProgressWatchdog(for: bookID)
        }
    }

    private func handleTransferCompletion(bookID: UUID, success: Bool, error: String?) {
        if activeTransferID == bookID {
            activeTransferID = nil
        }
        cancelAckTimeout(for: bookID)
        cancelOutboundTimeout(for: bookID)
        cancelConfirmationPoll(for: bookID)
        cancelProgressWatchdog(for: bookID)
        pendingSourceURLs.removeValue(forKey: bookID)
        pendingManifests.removeValue(forKey: bookID)
        if success {
            progressByBookID.removeValue(forKey: bookID)
        } else {
            setProgress(bookID: bookID, phase: .failed, errorMessage: error ?? "Transfer failed.")
        }
        notifyStateChanged()
        startNextTransferIfNeeded()
    }

    private func scheduleAckTimeout(for bookID: UUID) {
        cancelAckTimeout(for: bookID)
        ackTimeoutTasks[bookID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.ackTimeoutSeconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.pendingManifests[bookID] != nil else { return }
                self.handleTransferCompletion(
                    bookID: bookID,
                    success: false,
                    error: "Apple Watch didn't confirm the transfer. Open \(Brand.displayName) on your Watch and try again."
                )
            }
        }
    }

    private func cancelAckTimeout(for bookID: UUID) {
        ackTimeoutTasks[bookID]?.cancel()
        ackTimeoutTasks.removeValue(forKey: bookID)
    }

    private func scheduleOutboundTimeout(for bookID: UUID, fileByteCount: Int64) {
        cancelOutboundTimeout(for: bookID)
        let megabytes = max(1, fileByteCount / 1_048_576)
        let seconds = min(max(120, UInt64(megabytes) * 90), 2_400)
        outboundTimeoutTasks[bookID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(seconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.pendingManifests[bookID] != nil else { return }
                self.handleTransferCompletion(
                    bookID: bookID,
                    success: false,
                    error: "Transfer timed out. Open \(Brand.displayName) on your Watch and try again."
                )
            }
        }
    }

    private func cancelOutboundTimeout(for bookID: UUID) {
        outboundTimeoutTasks[bookID]?.cancel()
        outboundTimeoutTasks.removeValue(forKey: bookID)
    }

    private func startConfirmationPolling(for bookID: UUID) {
        cancelConfirmationPoll(for: bookID)
        confirmationPollTasks[bookID] = Task { [weak self] in
            guard let self else { return }
            for _ in 0..<Self.confirmationPollAttempts {
                guard !Task.isCancelled else { return }
                if self.isOnWatch(bookID: bookID) {
                    self.handleTransferCompletion(bookID: bookID, success: true, error: nil)
                    return
                }
                await self.refreshWatchLibraryState()
                if self.isOnWatch(bookID: bookID) {
                    self.handleTransferCompletion(bookID: bookID, success: true, error: nil)
                    return
                }
                try? await Task.sleep(for: .seconds(Self.confirmationPollIntervalSeconds))
            }
        }
    }

    private func cancelConfirmationPoll(for bookID: UUID) {
        confirmationPollTasks[bookID]?.cancel()
        confirmationPollTasks.removeValue(forKey: bookID)
    }

    private func startProgressWatchdog(for bookID: UUID) {
        cancelProgressWatchdog(for: bookID)
        progressWatchdogTasks[bookID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.pendingManifests[bookID] != nil else { return }
                if self.isOnWatch(bookID: bookID) {
                    self.handleTransferCompletion(bookID: bookID, success: true, error: nil)
                    return
                }
                let progress = self.progressByBookID[bookID]
                let fraction = progress?.fractionCompleted ?? 0
                guard fraction < 0.001 else { return }
                switch progress?.phase {
                case .starting, .transferring, .waitingForWatch:
                    self.setProgress(bookID: bookID, phase: .waitingForWatch, fractionCompleted: 0)
                default:
                    break
                }
            }

            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.pendingManifests[bookID] != nil else { return }
                Task {
                    await self.refreshWatchLibraryState()
                    if self.isOnWatch(bookID: bookID) {
                        self.handleTransferCompletion(bookID: bookID, success: true, error: nil)
                    }
                }
            }
        }
    }

    private func cancelProgressWatchdog(for bookID: UUID) {
        progressWatchdogTasks[bookID]?.cancel()
        progressWatchdogTasks.removeValue(forKey: bookID)
    }

    private func preflightTransferError() async -> String? {
        if !watchBridge.isPaired {
            return "No Apple Watch paired."
        }
        if !watchBridge.isWatchAppInstalled {
            return "Install \(Brand.displayName) on Apple Watch."
        }
        guard await watchBridge.ensureSessionActivated(timeout: 8) else {
            return "Could not connect to Apple Watch. Open \(Brand.displayName) on both devices."
        }
        return nil
    }

    private func notifyStateChanged() {
        stateRevision &+= 1
        onStateChanged?()
    }

    private func watchUnavailableMessage() -> String {
        if !watchBridge.isPaired {
            return "No Apple Watch paired."
        }
        if !watchBridge.isWatchAppInstalled {
            return "Install \(Brand.displayName) on Apple Watch."
        }
        return "Watch is not available. Open \(Brand.displayName) on both devices."
    }

    private func buildManifest(
        for audiobook: Audiobook,
        onHashProgress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> WatchTransferManifest {
        let sourceURL = audiobook.fileURL
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw WatchTransferError.fileMissing
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        let usedBytes = localBooks?.usedBytes ?? 0
        let budget = localBooks?.budgetBytes ?? WatchStorageBudget.defaultBudgetBytes
        if usedBytes + byteCount > budget {
            throw WatchTransferError.watchStorageFull
        }

        let sha256 = try await Task.detached(priority: .utility) {
            try Self.sha256(of: sourceURL, onProgress: onHashProgress)
        }.value

        let ext = sourceURL.pathExtension.lowercased()
        let chapters = audiobook.chapters
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                WatchChapterSummary(
                    id: $0.id,
                    title: $0.title,
                    startTime: $0.startTime,
                    duration: $0.duration,
                    orderIndex: $0.orderIndex
                )
            }

        let thumbnail = CoverArtCache.shared.image(for: audiobook)
            .flatMap { ThumbnailEncoder.jpegData(from: $0, size: .list) }

        return WatchTransferManifest(
            bookID: audiobook.id,
            title: audiobook.title,
            author: audiobook.author,
            duration: audiobook.duration,
            chapters: chapters,
            fileByteCount: byteCount,
            sha256: sha256,
            fileExtension: ext,
            thumbnailJPEG: thumbnail,
            resumePosition: audiobook.currentPlaybackTime
        )
    }

    private nonisolated static func sha256(
        of url: URL,
        onProgress: (@Sendable (Double) -> Void)? = nil
    ) throws -> String {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let totalBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        var processedBytes: Int64 = 0
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1_048_576)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            processedBytes += Int64(chunk.count)
            if totalBytes > 0, let onProgress {
                onProgress(Double(processedBytes) / Double(totalBytes))
            }
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    deinit {
        ackTimeoutTasks.values.forEach { $0.cancel() }
        outboundTimeoutTasks.values.forEach { $0.cancel() }
        confirmationPollTasks.values.forEach { $0.cancel() }
        progressWatchdogTasks.values.forEach { $0.cancel() }
    }
}

enum WatchTransferError: LocalizedError {
    case fileMissing
    case watchStorageFull

    var errorDescription: String? {
        switch self {
        case .fileMissing: return "Audiobook file is missing."
        case .watchStorageFull: return "Not enough space on Apple Watch."
        }
    }
}

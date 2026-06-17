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
    var localBooks: WatchLocalBooksPayload? { watchBridge.latestLocalBooks }

    private let watchBridge: any WatchConnectivityBridgeProtocol
    private var transferQueue: [UUID] = []
    private var activeTransferID: UUID?
    private var pendingManifests: [UUID: WatchTransferManifest] = [:]
    private var pendingSourceURLs: [UUID: URL] = [:]

    init(watchBridge: any WatchConnectivityBridgeProtocol) {
        self.watchBridge = watchBridge
        watchBridge.transferCompletionHandler = { [weak self] bookID, success, error in
            self?.handleTransferCompletion(bookID: bookID, success: success, error: error)
        }
    }

    func transfer(audiobook: Audiobook) async {
        await transfer(audiobooks: [audiobook])
    }

    func transfer(audiobooks: [Audiobook]) async {
        for audiobook in audiobooks {
            guard !isOnWatch(bookID: audiobook.id), !isTransferring(bookID: audiobook.id) else { continue }

            do {
                let manifest = try buildManifest(for: audiobook)
                pendingManifests[audiobook.id] = manifest
                pendingSourceURLs[audiobook.id] = audiobook.fileURL
                progressByBookID[audiobook.id] = WatchTransferProgress(bookID: audiobook.id, phase: .queued)
                transferQueue.append(audiobook.id)
            } catch {
                progressByBookID[audiobook.id] = WatchTransferProgress(
                    bookID: audiobook.id,
                    phase: .failed,
                    errorMessage: error.localizedDescription
                )
            }
        }
        startNextTransferIfNeeded()
    }

    func removeFromWatch(bookID: UUID) async {
        _ = await watchBridge.sendCommandToWatch(.deleteLocalBook(bookID: bookID))
    }

    func isOnWatch(bookID: UUID) -> Bool {
        localBooks?.books.contains(where: { $0.id == bookID }) == true
    }

    func isTransferring(bookID: UUID) -> Bool {
        guard let progress = progressByBookID[bookID] else { return false }
        return progress.phase == .queued || progress.phase == .transferring
    }

    func handleLocalBooksAcknowledgement(_ payload: WatchLocalBooksPayload) {
        watchBridge.publishLocalBooks(payload)
        for bookID in pendingManifests.keys where payload.books.contains(where: { $0.id == bookID }) {
            handleTransferCompletion(bookID: bookID, success: true, error: nil)
        }
    }

    // MARK: - Private

    private func startNextTransferIfNeeded() {
        guard activeTransferID == nil, let bookID = transferQueue.first else { return }
        transferQueue.removeFirst()
        guard let manifest = pendingManifests[bookID],
              let sourceURL = pendingSourceURLs[bookID] else { return }

        activeTransferID = bookID
        progressByBookID[bookID] = WatchTransferProgress(bookID: bookID, phase: .transferring)
        watchBridge.transferBook(manifest: manifest, fileURL: sourceURL)
    }

    private func handleTransferCompletion(bookID: UUID, success: Bool, error: String?) {
        if activeTransferID == bookID {
            activeTransferID = nil
        }
        pendingSourceURLs.removeValue(forKey: bookID)
        pendingManifests.removeValue(forKey: bookID)
        if success {
            progressByBookID[bookID] = WatchTransferProgress(bookID: bookID, phase: .complete)
        } else {
            progressByBookID[bookID] = WatchTransferProgress(
                bookID: bookID,
                phase: .failed,
                errorMessage: error ?? "Transfer failed."
            )
        }
        startNextTransferIfNeeded()
    }

    private func buildManifest(for audiobook: Audiobook) throws -> WatchTransferManifest {
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

        let sha256 = try Self.sha256(of: sourceURL)
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

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while autoreleasepool(invoking: {
            let chunk = handle.readData(ofLength: 1_048_576)
            if chunk.isEmpty { return false }
            hasher.update(data: chunk)
            return true
        }) {}
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
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

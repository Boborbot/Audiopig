//
//  WatchTransferServiceTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

/// Keeps `@MainActor` services alive through XCTest teardown to avoid Swift 6 deinit crashes in the host app.
@MainActor
private enum WatchTransferServiceTestRetention {
    static var services: [WatchTransferService] = []
    static var bridges: [MockWatchBridge] = []
}

@MainActor
final class WatchTransferServiceTests: XCTestCase {

    private func makeService() -> (MockWatchBridge, WatchTransferService) {
        let bridge = MockWatchBridge()
        let service = WatchTransferService(watchBridge: bridge)
        WatchTransferServiceTestRetention.bridges.append(bridge)
        WatchTransferServiceTestRetention.services.append(service)
        return (bridge, service)
    }

    func test_acknowledgementCompletesPendingTransfer() {
        let (bridge, service) = makeService()
        let bookID = UUID()
        let manifest = sampleManifest(bookID: bookID)

        service.testing_setPendingTransfer(bookID: bookID, manifest: manifest)
        XCTAssertTrue(service.isTransferring(bookID: bookID))

        let payload = WatchLocalBooksPayload(
            books: [
                WatchBookSummary(
                    id: bookID,
                    title: manifest.title,
                    author: manifest.author,
                    duration: manifest.duration,
                    currentPlaybackTime: 0,
                    lastPlayedAt: nil
                )
            ],
            usedBytes: manifest.fileByteCount,
            budgetBytes: WatchStorageBudget.defaultBudgetBytes
        )
        service.handleLocalBooksAcknowledgement(payload)

        XCTAssertTrue(service.isOnWatch(bookID: bookID))
        XCTAssertFalse(service.isTransferring(bookID: bookID))
        XCTAssertNil(service.transferFailureMessage(for: bookID))
    }

    func test_ingestFailureMarksTransferFailed() {
        let (_, service) = makeService()
        let bookID = UUID()

        service.testing_setPendingTransfer(bookID: bookID, manifest: sampleManifest(bookID: bookID))
        service.handleTransferFailure(bookID: bookID, errorMessage: "Checksum mismatch")

        XCTAssertEqual(service.transferFailureMessage(for: bookID), "Checksum mismatch")
        XCTAssertFalse(service.isTransferring(bookID: bookID))
    }

    func test_fileDeliveredWithoutPendingTransferIsIgnored() {
        let (_, service) = makeService()

        service.handleFileDelivered(bookID: UUID())

        XCTAssertEqual(service.progressByBookID.count, 0)
    }

    func test_reconcileClearsStuckProgressWhenBookAlreadyOnWatch() {
        let (bridge, service) = makeService()
        let bookID = UUID()
        let manifest = sampleManifest(bookID: bookID)

        bridge.latestLocalBooks = WatchLocalBooksPayload(
            books: [
                WatchBookSummary(
                    id: bookID,
                    title: manifest.title,
                    author: manifest.author,
                    duration: manifest.duration,
                    currentPlaybackTime: 0,
                    lastPlayedAt: nil
                )
            ],
            usedBytes: manifest.fileByteCount,
            budgetBytes: WatchStorageBudget.defaultBudgetBytes
        )
        service.testing_setPendingTransfer(bookID: bookID, manifest: manifest)
        service.handleLocalBooksAcknowledgement(bridge.latestLocalBooks!)

        XCTAssertTrue(service.isOnWatch(bookID: bookID))
        XCTAssertFalse(service.isTransferring(bookID: bookID))
    }

    func test_stateRevisionBumpsOnProgressChanges() {
        let (_, service) = makeService()
        let bookID = UUID()
        var callbackCount = 0
        service.onStateChanged = { callbackCount += 1 }

        let revisionBefore = service.stateRevision
        service.testing_setPendingTransfer(bookID: bookID, manifest: sampleManifest(bookID: bookID))
        service.handleTransferFailure(bookID: bookID, errorMessage: "Failed")

        XCTAssertGreaterThan(service.stateRevision, revisionBefore)
        XCTAssertGreaterThan(callbackCount, 0)
    }

    private func sampleManifest(bookID: UUID) -> WatchTransferManifest {
        WatchTransferManifest(
            bookID: bookID,
            title: "Test Book",
            author: "Author",
            duration: 120,
            chapters: [],
            fileByteCount: 1_024,
            sha256: "abc",
            fileExtension: "m4b"
        )
    }
}

@MainActor
private final class MockWatchBridge: WatchConnectivityBridgeProtocol {
    var isPaired = true
    var isWatchAppInstalled = true
    var isReachable = true
    var latestLocalBooks: WatchLocalBooksPayload?
    var commandHandler: (@MainActor (WatchCommand) async -> WatchCommandResult)?
    var transferCompletionHandler: (@MainActor (UUID, Bool, String?) -> Void)?
    var fileDeliveredHandler: (@MainActor (UUID) -> Void)?
    var fileProgressHandler: (@MainActor (UUID, Double) -> Void)?
    var reachabilityHandler: (@MainActor (Bool) -> Void)?
    var isSessionActivated: Bool { true }

    func activate() {}

    func publishSnapshot(_ snapshot: WatchPlaybackSnapshot, includeArtwork: Bool) {}

    func publishChapters(_ payload: WatchChaptersPayload) {}

    func publishRecentBooks(_ payload: WatchRecentBooksPayload) {}

    func publishLocalBooks(_ payload: WatchLocalBooksPayload) {
        latestLocalBooks = payload
    }

    func publishSettings(_ settings: WatchSettingsSnapshot) {}

    func restoreLocalBooksCache(_ payload: WatchLocalBooksPayload) {
        latestLocalBooks = payload
    }

    @discardableResult
    func transferBook(manifest: WatchTransferManifest, fileURL: URL) async -> Bool { true }

    func ensureSessionActivated(timeout: TimeInterval) async -> Bool { true }

    func cancelTransfer(bookID: UUID) {}

    func sendCommandToWatch(_ command: WatchCommand) async -> WatchCommandResult { .ok() }
}

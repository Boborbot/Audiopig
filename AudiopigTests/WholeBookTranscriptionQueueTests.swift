//
//  WholeBookTranscriptionQueueTests.swift
//  AudiopigTests
//

import XCTest
import SwiftData
@testable import Audiopig

@MainActor
final class WholeBookTranscriptionQueueTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var queue: WholeBookTranscriptionQueueService!

    override func setUpWithError() throws {
        container = try AudiopigModelContainer.make(isStoredInMemoryOnly: true)
        context = ModelContext(container)
        queue = WholeBookTranscriptionQueueService(
            modelContext: context,
            subtitleStore: SubtitleStore(modelContext: context),
            transcriptionService: SubtitleTranscriptionService(),
            monetization: MockMonetizationService(hasSubtitles: true),
            localeProvider: { "en-US" }
        )
    }

    override func tearDownWithError() throws {
        queue = nil
        context = nil
        container = nil
    }

    func test_enqueue_deduplicatesSameBook() throws {
        let book = makeAudiobook(duration: 600)
        context.insert(book)
        try context.save()

        XCTAssertEqual(queue.enqueue(audiobookID: book.id), .enqueued)
        XCTAssertEqual(queue.enqueue(audiobookID: book.id), .alreadyInQueue)
        XCTAssertEqual(queue.queueCount, 1)
    }

    func test_moveEntry_doesNotMoveRunningItem() throws {
        let first = makeAudiobook(title: "First", duration: 600)
        let second = makeAudiobook(title: "Second", duration: 600)
        context.insert(first)
        context.insert(second)
        try context.save()

        _ = queue.enqueue(audiobookID: first.id)
        _ = queue.enqueue(audiobookID: second.id)

        let entry = try XCTUnwrap(fetchEntries().first { $0.audiobook?.id == first.id })
        entry.status = .running
        try context.save()

        queue.moveEntry(from: IndexSet(integer: 1), to: 0)
        let orderedTitles = queue.allSnapshots().map(\.title)
        XCTAssertEqual(orderedTitles, ["First", "Second"])
    }

    func test_cancel_removesEntry() throws {
        let book = makeAudiobook(duration: 600)
        context.insert(book)
        try context.save()

        _ = queue.enqueue(audiobookID: book.id)
        XCTAssertEqual(queue.queueCount, 1)

        queue.cancel(audiobookID: book.id)
        XCTAssertFalse(queue.hasQueueUI)
    }

    func test_snapshotMapper_mapsRunningToJobState() {
        let snapshot = WholeBookQueueItemSnapshot(
            id: UUID(),
            audiobookID: UUID(),
            title: "Book",
            author: "Author",
            queuePosition: 1,
            status: .running,
            isPreparing: false,
            coverageFraction: 0.25,
            completedWindows: 2,
            totalWindows: 8,
            progressMessage: "Transcribing entire book (3 of 6)…",
            failureMessage: nil
        )

        let state = WholeBookQueueSnapshotMapper.jobState(from: snapshot)
        guard case .running(let completed, let total, _) = state else {
            return XCTFail("Expected running state")
        }
        XCTAssertEqual(completed, 2)
        XCTAssertEqual(total, 8)
    }

    private func makeAudiobook(title: String = "Test Book", duration: TimeInterval) -> Audiobook {
        Audiobook(
            title: title,
            author: "Author",
            duration: duration,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).m4b")
        )
    }

    private func fetchEntries() -> [WholeBookTranscriptionQueueEntry] {
        let descriptor = FetchDescriptor<WholeBookTranscriptionQueueEntry>(
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}

@MainActor
private final class MockMonetizationService: MonetizationServiceProtocol {
    let hasSubtitles: Bool
    var hasPlusSubscription: Bool { hasSubtitles }
    var isEligibleForIntroOffer: Bool = false
    var isInTrialPeriod: Bool = false
    var subscriptionExpirationDate: Date? = nil
    var plusDisplayPrice: String? = nil
    var plusRenewalDescription: String? = nil

    init(hasSubtitles: Bool) {
        self.hasSubtitles = hasSubtitles
    }

    func displayPrice(for tier: TipTier) -> String? { nil }

    func hasAccess(to feature: PremiumFeature) -> Bool {
        feature == .subtitles ? hasSubtitles : false
    }

    func refreshEntitlements() async {}
    func loadProducts() async {}
    func purchasePlus() async throws {}
    func purchaseTip(_ tier: TipTier) async throws {}
    func restorePurchases() async throws {}
    func startTransactionListener() {}
}

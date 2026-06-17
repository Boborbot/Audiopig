//
//  WatchSnapshotFreshnessTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class WatchSnapshotFreshnessTests: XCTestCase {

    func test_rejectsOlderRevisionForSameBookAndSource() {
        let last = sample(revision: 10, bookID: bookA, source: .remote)
        let incoming = sample(revision: 9, bookID: bookA, source: .remote)
        XCTAssertTrue(WatchSnapshotFreshness.shouldReject(incoming: incoming, comparedTo: last))
    }

    func test_acceptsNewerRevisionForSameBookAndSource() {
        let last = sample(revision: 10, bookID: bookA, source: .remote)
        let incoming = sample(revision: 11, bookID: bookA, source: .remote)
        XCTAssertFalse(WatchSnapshotFreshness.shouldReject(incoming: incoming, comparedTo: last))
    }

    func test_acceptsRemoteUpdateAfterLocalPlaybackEvenWithLowerRevision() {
        let last = sample(revision: 50, bookID: bookA, source: .local)
        let incoming = sample(revision: 3, bookID: bookB, source: .remote)
        XCTAssertFalse(WatchSnapshotFreshness.shouldReject(incoming: incoming, comparedTo: last))
    }

    func test_acceptsSourceChangeForSameBook() {
        let last = sample(revision: 20, bookID: bookA, source: .local)
        let incoming = sample(revision: 5, bookID: bookA, source: .remote)
        XCTAssertFalse(WatchSnapshotFreshness.shouldReject(incoming: incoming, comparedTo: last))
    }

    private let bookA = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    private let bookB = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!

    private func sample(
        revision: UInt64,
        bookID: UUID,
        source: WatchPlaybackSource
    ) -> WatchPlaybackSnapshot {
        WatchPlaybackSnapshot(
            revision: revision,
            bookID: bookID,
            title: "Title",
            author: "Author",
            chapterTitle: "Chapter",
            playbackState: .playing,
            playbackSpeed: 1,
            skipForwardSeconds: 30,
            skipBackwardSeconds: 15,
            chapterIndex: 0,
            chapterCount: 1,
            chapterElapsed: 0,
            chapterDuration: 100,
            chapterProgress: 0,
            globalCurrentTime: 0,
            globalDuration: 100,
            systemVolume: 0.5,
            source: source,
            artworkJPEG: nil
        )
    }
}

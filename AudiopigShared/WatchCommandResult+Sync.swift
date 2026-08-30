//
//  WatchCommandResult+Sync.swift
//  AudiopigShared
//

import Foundation

extension WatchCommandResult {
    /// Ensures the encoded reply fits within `sendMessage` limits.
    public func messageReplyPayload(
        maxBytes: Int = WatchApplicationContextBudget.messageMaxBytes
    ) -> WatchCommandResult {
        if WatchApplicationContextBudget.encodedByteCount(self) <= maxBytes {
            return self
        }

        let candidates: [WatchCommandResult] = [
            trimmed(stripArtwork: true, stripChapters: false, stripRecentBooks: false),
            trimmed(stripArtwork: false, stripChapters: true, stripRecentBooks: false),
            trimmed(stripArtwork: true, stripChapters: true, stripRecentBooks: false),
            trimmed(stripArtwork: true, stripChapters: true, stripRecentBooks: true)
        ]

        for candidate in candidates {
            if WatchApplicationContextBudget.encodedByteCount(candidate) <= maxBytes {
                return candidate
            }
        }

        if let recentBooks {
            let slimRecent = trimmed(
                stripArtwork: true,
                stripChapters: true,
                stripRecentBooks: false,
                recentBooksOverride: recentBooks.messageReplyPayload(maxBytes: maxBytes)
            )
            if WatchApplicationContextBudget.encodedByteCount(slimRecent) <= maxBytes {
                return slimRecent
            }
        }

        return trimmed(stripArtwork: true, stripChapters: true, stripRecentBooks: true)
    }

    private func trimmed(
        stripArtwork: Bool,
        stripChapters: Bool,
        stripRecentBooks: Bool,
        recentBooksOverride: WatchRecentBooksPayload? = nil
    ) -> WatchCommandResult {
        let resolvedSnapshot: WatchPlaybackSnapshot?
        if stripArtwork, let snapshot, snapshot.artworkJPEG != nil {
            resolvedSnapshot = snapshot.withArtworkJPEG(nil)
        } else {
            resolvedSnapshot = snapshot
        }

        let resolvedRecentBooks: WatchRecentBooksPayload?
        if let recentBooksOverride {
            resolvedRecentBooks = recentBooksOverride
        } else if stripRecentBooks {
            resolvedRecentBooks = nil
        } else {
            resolvedRecentBooks = recentBooks
        }

        return WatchCommandResult(
            success: success,
            errorMessage: errorMessage,
            snapshot: resolvedSnapshot,
            lullResult: lullResult,
            localBooks: localBooks,
            recentBooks: resolvedRecentBooks,
            chapters: stripChapters ? nil : chapters
        )
    }
}

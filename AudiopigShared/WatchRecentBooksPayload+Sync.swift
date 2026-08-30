//
//  WatchRecentBooksPayload+Sync.swift
//  AudiopigShared
//

import Foundation

extension WatchRecentBooksPayload {
    /// Metadata-only copy — used when only playback positions changed.
    public func metadataOnlyCopy() -> WatchRecentBooksPayload {
        slimSyncCopy()
    }

    /// Application-context copy: keep thumbnails for the first `thumbnailCount` books when possible.
    public func contextSyncCopy(thumbnailCount: Int = 10) -> WatchRecentBooksPayload {
        guard thumbnailCount > 0 else { return slimSyncCopy() }
        let capped = min(thumbnailCount, books.count)
        let withThumbs = books.prefix(capped)
        let withoutThumbs = books.dropFirst(capped).map { book in
            WatchBookSummary(
                id: book.id,
                title: book.title,
                author: book.author,
                duration: book.duration,
                currentPlaybackTime: book.currentPlaybackTime,
                lastPlayedAt: book.lastPlayedAt,
                thumbnailJPEG: nil
            )
        }
        return WatchRecentBooksPayload(books: Array(withThumbs) + withoutThumbs)
    }

    /// Active-session reply: prefer full thumbnails, degrade only if over the message budget.
    public func messageReplyPayload(
        maxBytes: Int = WatchApplicationContextBudget.messageMaxBytes
    ) -> WatchRecentBooksPayload {
        if WatchApplicationContextBudget.encodedByteCount(self) <= maxBytes {
            return self
        }

        for thumbCount in stride(from: books.count, through: 1, by: -1) {
            let candidate = contextSyncCopy(thumbnailCount: thumbCount)
            if WatchApplicationContextBudget.encodedByteCount(candidate) <= maxBytes {
                return candidate
            }
        }

        let slim = slimSyncCopy()
        if WatchApplicationContextBudget.encodedByteCount(slim) <= maxBytes {
            return slim
        }

        var trimmed = slim.books
        while !trimmed.isEmpty {
            trimmed.removeLast()
            let candidate = WatchRecentBooksPayload(books: trimmed)
            if WatchApplicationContextBudget.encodedByteCount(candidate) <= maxBytes {
                return candidate
            }
        }
        return WatchRecentBooksPayload(books: [])
    }
}

extension WatchChaptersPayload {
    /// Active-session reply: full chapter list when it fits; otherwise keep a window around the playhead.
    public func messageReplyPayload(
        maxBytes: Int = WatchApplicationContextBudget.messageMaxBytes,
        prioritizingChapterIndex: Int? = nil
    ) -> WatchChaptersPayload {
        if WatchApplicationContextBudget.encodedByteCount(self) <= maxBytes {
            return self
        }

        guard !chapters.isEmpty else { return self }

        let focus = prioritizingChapterIndex.map {
            min(max(0, $0), chapters.count - 1)
        } ?? 0

        var radius = 0
        while radius < chapters.count {
            let lower = max(0, focus - radius)
            let upper = min(chapters.count - 1, focus + radius)
            let slice = Array(chapters[lower...upper])
            let candidate = WatchChaptersPayload(bookID: bookID, chapters: slice)
            if WatchApplicationContextBudget.encodedByteCount(candidate) <= maxBytes {
                return candidate
            }
            radius += 1
        }

        return WatchChaptersPayload(bookID: bookID, chapters: [chapters[focus]])
    }
}

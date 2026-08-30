//
//  WatchSnapshotFreshness.swift
//  AudiopigShared
//

import Foundation

enum WatchSnapshotFreshness {
    /// Reject only when the incoming snapshot is older within the same book/source stream.
    /// Revisions are independent per device, so cross-source or book-change updates always apply.
    /// `updatedAt` is the primary signal so iPhone app restarts (revision reset) still sync.
    static func shouldReject(
        incoming: WatchPlaybackSnapshot,
        comparedTo last: WatchPlaybackSnapshot
    ) -> Bool {
        let sameStream = incoming.source == last.source
            && incoming.bookID == last.bookID
        guard sameStream else { return false }

        if incoming.updatedAt > last.updatedAt { return false }
        if incoming.updatedAt < last.updatedAt { return true }
        return incoming.revision < last.revision
    }
}

//
//  WatchSnapshotFreshness.swift
//  AudiopigShared
//

import Foundation

enum WatchSnapshotFreshness {
    /// Reject only when the incoming snapshot is older within the same book/source stream.
    /// Revisions are independent per device, so cross-source or book-change updates always apply.
    static func shouldReject(
        incoming: WatchPlaybackSnapshot,
        comparedTo last: WatchPlaybackSnapshot
    ) -> Bool {
        let sameStream = incoming.source == last.source
            && incoming.bookID == last.bookID
        guard sameStream else { return false }
        return incoming.revision < last.revision
    }
}

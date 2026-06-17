//
//  Audiobook+LibrarySort.swift
//  Audiopig
//

import Foundation

extension Audiobook {
    var effectiveAddedAt: Date {
        addedAt ?? fileAdditionDate ?? .distantPast
    }

    var fileSizeBytes: Int64 {
        (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
    }

    func librarySortCandidate() -> LibrarySortCandidate {
        LibrarySortCandidate(
            id: id,
            title: title,
            author: author,
            duration: duration,
            lastPlayedAt: lastPlayedAt,
            addedAt: effectiveAddedAt,
            fileSize: fileSizeBytes
        )
    }

    private var fileAdditionDate: Date? {
        guard let values = try? fileURL.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey]) else {
            return nil
        }
        return values.creationDate ?? values.contentModificationDate
    }
}

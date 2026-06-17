//
//  WidgetSnapshotWriter.swift
//  Audiopig
//
//  Pushes listening stats into the shared App Group store and reloads widget timelines.
//

import Foundation
import UIKit
import WidgetKit

enum WidgetSnapshotWriter {

    private static var lastReloadDate: Date?
    private static let reloadThrottle: TimeInterval = 30

    static func updateLastPlayed(
        title: String,
        author: String,
        audiobookID: UUID? = nil,
        coverImage: UIImage? = nil
    ) {
        WidgetListeningSnapshot.updateLastPlayed(
            title: title,
            author: author,
            audiobookID: audiobookID?.uuidString
        )
        if audiobookID != nil, let coverImage {
            WidgetArtworkExporter.exportCover(image: coverImage)
        }
        reloadWidgets()
    }

    static func recordListeningDelta(_ delta: TimeInterval) {
        WidgetListeningSnapshot.addTodayListening(delta)
        reloadWidgetsIfNeeded()
    }

    static func syncRecentBooks(books: [WatchBookSummary]) {
        WidgetRecentBooksExporter.sync(books: books)
        reloadWidgets()
    }

    static func reloadWidgets() {
        lastReloadDate = .now
        for kind in WidgetListeningSnapshot.allWidgetKinds {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    private static func reloadWidgetsIfNeeded() {
        let now = Date()
        if let lastReloadDate, now.timeIntervalSince(lastReloadDate) < reloadThrottle {
            return
        }
        reloadWidgets()
    }
}

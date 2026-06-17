//
//  WidgetRecentBooksSnapshot.swift
//  AudiopigShared
//

import Foundation

enum WidgetRecentBooksSnapshot {

    static let widgetKind = "RecentBooksWidget"
    private static let booksKey = "widget.recentBooksJSON"

    struct Book: Codable, Equatable, Identifiable {
        let id: UUID
        let title: String
        let thumbnailFilename: String
    }

    struct Data: Equatable {
        let books: [Book]
    }

    // MARK: - Read

    static func load() -> Data {
        guard let defaults = sharedDefaults(),
              let data = defaults.data(forKey: booksKey),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return Data(books: [])
        }
        return Data(books: books)
    }

    static func thumbnailURL(for book: Book) -> URL? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetListeningSnapshot.appGroupID
        ) else { return nil }
        let url = container.appendingPathComponent(book.thumbnailFilename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    static func thumbnailFilename(for id: UUID) -> String {
        "widget-recent-\(id.uuidString).jpg"
    }

    // MARK: - Write (app only)

    static func save(books: [Book]) {
        guard let defaults = sharedDefaults(),
              let data = try? JSONEncoder().encode(books) else { return }
        defaults.set(data, forKey: booksKey)
        defaults.set(Date(), forKey: "widget.snapshotUpdatedAt")
    }

    // MARK: - Deep links

    static func playURL(for bookID: UUID) -> URL {
        URL(string: "audiopig://play/\(bookID.uuidString)")!
    }

    // MARK: - Private

    private static func sharedDefaults() -> UserDefaults? {
        UserDefaults(suiteName: WidgetListeningSnapshot.appGroupID)
    }
}

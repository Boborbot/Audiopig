//
//  WidgetRecentBooksExporter.swift
//  Audiopig
//

import UIKit

enum WidgetRecentBooksExporter {

    private static let maxBooks = 5
    private static let jpegQuality: CGFloat = 0.82
    private static let thumbnailSize: CGFloat = 200

    static func sync(books: [WatchBookSummary]) {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: WidgetListeningSnapshot.appGroupID
        ) else { return }

        let selected = Array(books.prefix(maxBooks))
        var entries: [WidgetRecentBooksSnapshot.Book] = []
        var activeFilenames = Set<String>()

        for book in selected {
            let filename = WidgetRecentBooksSnapshot.thumbnailFilename(for: book.id)
            activeFilenames.insert(filename)
            let url = container.appendingPathComponent(filename)

            if let jpeg = book.thumbnailJPEG ?? placeholderJPEG(title: book.title) {
                try? jpeg.write(to: url, options: .atomic)
            }

            entries.append(
                WidgetRecentBooksSnapshot.Book(
                    id: book.id,
                    title: book.title,
                    thumbnailFilename: filename
                )
            )
        }

        WidgetRecentBooksSnapshot.save(books: entries)
        removeOrphanedThumbnails(activeFilenames: activeFilenames, in: container)
    }

    private static func placeholderJPEG(title: String) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: thumbnailSize, height: thumbnailSize))
        let image = renderer.image { context in
            UIColor.systemGray4.setFill()
            context.fill(CGRect(x: 0, y: 0, width: thumbnailSize, height: thumbnailSize))
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: UIColor.secondaryLabel,
                .paragraphStyle: paragraph
            ]
            let initial = String(title.prefix(1)).uppercased()
            initial.draw(
                in: CGRect(x: 0, y: (thumbnailSize - 34) / 2, width: thumbnailSize, height: 34),
                withAttributes: attrs
            )
        }
        return image.jpegData(compressionQuality: jpegQuality)
    }

    private static func removeOrphanedThumbnails(activeFilenames: Set<String>, in container: URL) {
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: container.path) else { return }
        for file in files where file.hasPrefix("widget-recent-") && !activeFilenames.contains(file) {
            try? FileManager.default.removeItem(at: container.appendingPathComponent(file))
        }
    }
}

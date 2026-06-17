//
//  RecentBooksWidget.swift
//  AudiopigWidget
//

import WidgetKit
import SwiftUI
import UIKit

// MARK: - Entry

struct RecentBooksEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetRecentBooksSnapshot.Data
    let thumbnails: [UUID: UIImage]
}

// MARK: - Provider

struct RecentBooksProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentBooksEntry {
        RecentBooksEntry(
            date: .now,
            snapshot: .init(
                books: [
                    .init(id: UUID(), title: "Dune", thumbnailFilename: "placeholder"),
                    .init(id: UUID(), title: "1984", thumbnailFilename: "placeholder"),
                    .init(id: UUID(), title: "Neuromancer", thumbnailFilename: "placeholder"),
                ]
            ),
            thumbnails: [:]
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentBooksEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentBooksEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> RecentBooksEntry {
        let snapshot = WidgetRecentBooksSnapshot.load()
        var thumbnails: [UUID: UIImage] = [:]
        for book in snapshot.books {
            if let url = WidgetRecentBooksSnapshot.thumbnailURL(for: book),
               let image = UIImage(contentsOfFile: url.path) {
                thumbnails[book.id] = image
            }
        }
        return RecentBooksEntry(date: .now, snapshot: snapshot, thumbnails: thumbnails)
    }
}

// MARK: - Widget

struct RecentBooksWidget: Widget {
    let kind = WidgetRecentBooksSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentBooksProvider()) { entry in
            RecentBooksWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    RecentBooksPalette.canvas
                }
        }
        .configurationDisplayName("Recent Books")
        .description("Recently listened audiobooks. Tap to play.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

private struct RecentBooksWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: RecentBooksEntry

    private var isMedium: Bool { widgetFamily == .systemMedium }
    private var tileSize: CGFloat { isMedium ? 72 : 56 }
    private var visibleBooks: [WidgetRecentBooksSnapshot.Book] {
        let limit = isMedium ? 5 : 3
        return Array(entry.snapshot.books.prefix(limit))
    }

    var body: some View {
        if entry.snapshot.books.isEmpty {
            emptyState
        } else {
            HStack(spacing: isMedium ? RecentBooksSpacing.md : RecentBooksSpacing.sm) {
                ForEach(visibleBooks) { book in
                    bookTile(book)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(isMedium ? RecentBooksSpacing.lg : RecentBooksSpacing.md)
        }
    }

    private var emptyState: some View {
        VStack(spacing: RecentBooksSpacing.sm) {
            Image(systemName: "books.vertical")
                .font(.title2)
                .foregroundStyle(RecentBooksPalette.coral)
            Text("No recent books")
                .font(.caption.weight(.medium))
                .foregroundStyle(RecentBooksPalette.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func bookTile(_ book: WidgetRecentBooksSnapshot.Book) -> some View {
        Link(destination: WidgetRecentBooksSnapshot.playURL(for: book.id)) {
            VStack(spacing: RecentBooksSpacing.xs) {
                Group {
                    if let image = entry.thumbnails[book.id] {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(RecentBooksPalette.coral.opacity(0.15))
                            .overlay {
                                Text(String(book.title.prefix(1)).uppercased())
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(RecentBooksPalette.coral)
                            }
                    }
                }
                .frame(width: tileSize, height: tileSize)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                if isMedium {
                    Text(book.title)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(RecentBooksPalette.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(width: tileSize)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Tokens

private enum RecentBooksPalette {
    static let coral = Color(red: 0xF1 / 255, green: 0x84 / 255, blue: 0x70 / 255)
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let canvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x14 / 255, green: 0x15 / 255, blue: 0x18 / 255, alpha: 1)
            : UIColor(red: 0xDD / 255, green: 0xD3 / 255, blue: 0xC5 / 255, alpha: 1)
    })
}

private enum RecentBooksSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 10
    static let lg: CGFloat = 14
}

// MARK: - Preview

#if DEBUG
struct RecentBooksWidget_Previews: PreviewProvider {
    static var previews: some View {
        RecentBooksWidgetView(
            entry: RecentBooksEntry(
                date: .now,
                snapshot: WidgetRecentBooksSnapshot.load(),
                thumbnails: [:]
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif

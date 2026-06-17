//
//  ListeningArtworkWidget.swift
//  AudiopigWidget
//

import WidgetKit
import SwiftUI
import UIKit

// MARK: - Entry

struct ListeningArtworkEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetListeningSnapshot.Data
    let coverImage: UIImage?
}

// MARK: - Provider

struct ListeningArtworkProvider: TimelineProvider {
    func placeholder(in context: Context) -> ListeningArtworkEntry {
        ListeningArtworkEntry(
            date: .now,
            snapshot: .init(
                lastPlayedTitle: "The Great Gatsby",
                lastPlayedAuthor: "F. Scott Fitzgerald",
                lastPlayedAudiobookID: nil,
                todayListenedSeconds: 7_200,
                snapshotUpdatedAt: .now,
                theme: .fallback,
                hasCoverArtwork: true
            ),
            coverImage: nil
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ListeningArtworkEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ListeningArtworkEntry>) -> Void) {
        let entry = makeEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> ListeningArtworkEntry {
        let snapshot = WidgetListeningSnapshot.load()
        let coverImage = snapshot.hasCoverArtwork
            ? WidgetListeningSnapshot.coverArtworkURL().flatMap { UIImage(contentsOfFile: $0.path) }
            : nil
        return ListeningArtworkEntry(date: .now, snapshot: snapshot, coverImage: coverImage)
    }
}

// MARK: - Widget

struct ListeningArtworkWidget: Widget {
    let kind = WidgetListeningSnapshot.artworkWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ListeningArtworkProvider()) { entry in
            ListeningArtworkWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetThemeBackground(theme: entry.snapshot.theme)
                }
        }
        .configurationDisplayName("Listening + Artwork")
        .description("Today's listening time with cover art colors.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - View

private struct ListeningArtworkWidgetView: View {
    let entry: ListeningArtworkEntry

    private var theme: WidgetListeningSnapshot.Theme { entry.snapshot.theme }

    var body: some View {
        VStack(spacing: WidgetSpacing.xs) {
            coverArtwork
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(WidgetListeningSnapshot.formatTodayListeningHoursMinutes(entry.snapshot.todayListenedSeconds))
                .font(.caption.weight(.medium))
                .foregroundStyle(themeColor(theme.secondaryText))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .padding(WidgetSpacing.sm)
    }

    @ViewBuilder
    private var coverArtwork: some View {
        if let coverImage = entry.coverImage {
            Image(uiImage: coverImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(themeColor(theme.accent).opacity(0.35), lineWidth: 1)
                }
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(themeColor(theme.accent).opacity(0.22))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay {
                    Image(systemName: "book.closed.fill")
                        .font(.title)
                        .foregroundStyle(themeColor(theme.primaryText).opacity(0.7))
                }
        }
    }
}

// MARK: - Theme helpers

private struct WidgetThemeBackground: View {
    let theme: WidgetListeningSnapshot.Theme

    var body: some View {
        LinearGradient(
            colors: [
                themeColor(theme.background),
                themeColor(theme.accent).opacity(0.88)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

private func themeColor(_ rgb: WidgetListeningSnapshot.RGB) -> Color {
    Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
}

private enum WidgetSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
}

// MARK: - Preview

#if DEBUG
struct ListeningArtworkWidget_Previews: PreviewProvider {
    static var previews: some View {
        ListeningArtworkWidgetView(
            entry: ListeningArtworkEntry(
                date: .now,
                snapshot: .init(
                    lastPlayedTitle: "Project Hail Mary",
                    lastPlayedAuthor: "Andy Weir",
                    lastPlayedAudiobookID: nil,
                    todayListenedSeconds: 8_640,
                    snapshotUpdatedAt: .now,
                    theme: WidgetListeningSnapshot.Theme(
                        background: .init(red: 0.12, green: 0.18, blue: 0.28),
                        accent: .init(red: 0.28, green: 0.42, blue: 0.62),
                        primaryText: .init(red: 1, green: 1, blue: 1),
                        secondaryText: .init(red: 0.86, green: 0.88, blue: 0.92)
                    ),
                    hasCoverArtwork: false
                ),
                coverImage: nil
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif

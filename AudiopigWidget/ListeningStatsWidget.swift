//
//  ListeningStatsWidget.swift
//  AudiopigWidget
//

import WidgetKit
import SwiftUI
import UIKit

// MARK: - Entry

struct ListeningStatsEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetListeningSnapshot.Data
}

// MARK: - Provider

struct ListeningStatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> ListeningStatsEntry {
        ListeningStatsEntry(
            date: .now,
            snapshot: .init(
                lastPlayedTitle: "The Great Gatsby",
                lastPlayedAuthor: "F. Scott Fitzgerald",
                lastPlayedAudiobookID: nil,
                lastPlayedProgress: 0,
                todayListenedSeconds: 7_200,
                snapshotUpdatedAt: .now,
                theme: .fallback,
                hasCoverArtwork: false
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ListeningStatsEntry) -> Void) {
        completion(ListeningStatsEntry(date: .now, snapshot: WidgetListeningSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ListeningStatsEntry>) -> Void) {
        let entry = ListeningStatsEntry(date: .now, snapshot: WidgetListeningSnapshot.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget

struct ListeningStatsWidget: Widget {
    let kind = WidgetListeningSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ListeningStatsProvider()) { entry in
            ListeningStatsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetPalette.canvas
                }
        }
        .configurationDisplayName("Listening")
        .description("Today's listening time and your last audiobook.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - View

private struct ListeningStatsWidgetView: View {
    let entry: ListeningStatsEntry

    var body: some View {
        if let playURL = WidgetListeningSnapshot.playURL(for: entry.snapshot) {
            Link(destination: playURL) {
                widgetContent
            }
        } else {
            widgetContent
        }
    }

    private var widgetContent: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: WidgetSpacing.xs) {
                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    Text(WidgetListeningSnapshot.formatTodayListening(entry.snapshot.todayListenedSeconds))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(WidgetPalette.primary)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                }
                .padding(.top, WidgetBrandSpacing.prominentContentTopPadding)

                Spacer(minLength: 0)

                VStack(alignment: .leading, spacing: 2) {
                    if entry.snapshot.lastPlayedTitle.isEmpty {
                        Text("No audiobook yet")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetPalette.primary)
                            .lineLimit(2)
                    } else {
                        Text(entry.snapshot.lastPlayedTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WidgetPalette.primary)
                            .lineLimit(2)
                        if !entry.snapshot.lastPlayedAuthor.isEmpty {
                            Text(entry.snapshot.lastPlayedAuthor)
                                .font(.caption2)
                                .foregroundStyle(WidgetPalette.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding(WidgetSpacing.md)

            WidgetBrandBadge(size: WidgetBrandSpacing.prominentBadgeSize)
                .padding(WidgetBrandSpacing.badgeInset)
        }
    }
}

// MARK: - Widget-local tokens

private enum WidgetPalette {
    static let coral = Color(red: 0xF1 / 255, green: 0x84 / 255, blue: 0x70 / 255)
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let canvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x14 / 255, green: 0x15 / 255, blue: 0x18 / 255, alpha: 1)
            : UIColor(red: 0xDD / 255, green: 0xD3 / 255, blue: 0xC5 / 255, alpha: 1)
    })
}

private enum WidgetSpacing {
    static let xs: CGFloat = 4
    static let md: CGFloat = 14
}

// MARK: - Preview

#if DEBUG
struct ListeningStatsWidget_Previews: PreviewProvider {
    static var previews: some View {
        ListeningStatsWidgetView(
            entry: ListeningStatsEntry(
                date: .now,
                snapshot: .init(
                    lastPlayedTitle: "Project Hail Mary",
                    lastPlayedAuthor: "Andy Weir",
                    lastPlayedAudiobookID: nil,
                    lastPlayedProgress: 0.72,
                    todayListenedSeconds: 8_640,
                    snapshotUpdatedAt: .now,
                    theme: .fallback,
                    hasCoverArtwork: false
                )
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemSmall))
    }
}
#endif

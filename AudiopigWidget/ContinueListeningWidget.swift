//
//  ContinueListeningWidget.swift
//  AudiopigWidget
//
//  Lock screen circular widget — progress ring and book title for the last listened audiobook.
//

import AppIntents
import WidgetKit
import SwiftUI

// MARK: - Entry

struct ContinueListeningEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetListeningSnapshot.Data
}

// MARK: - Provider

struct ContinueListeningProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContinueListeningEntry {
        ContinueListeningEntry(
            date: .now,
            snapshot: .init(
                lastPlayedTitle: "The Great Gatsby",
                lastPlayedAuthor: "F. Scott Fitzgerald",
                lastPlayedAudiobookID: UUID().uuidString,
                lastPlayedProgress: 0.42,
                todayListenedSeconds: 0,
                snapshotUpdatedAt: .now,
                theme: .fallback,
                hasCoverArtwork: false
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (ContinueListeningEntry) -> Void) {
        completion(ContinueListeningEntry(date: .now, snapshot: WidgetListeningSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueListeningEntry>) -> Void) {
        let entry = ContinueListeningEntry(date: .now, snapshot: WidgetListeningSnapshot.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget

struct ContinueListeningWidget: Widget {
    let kind = WidgetListeningSnapshot.continueListeningWidgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ContinueListeningProvider()) { entry in
            ContinueListeningWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Continue Listening")
        .description("Your last audiobook with reading progress.")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - View

private struct ContinueListeningWidgetView: View {
    let entry: ContinueListeningEntry

    private var snapshot: WidgetListeningSnapshot.Data { entry.snapshot }

    private var hasBook: Bool {
        !snapshot.lastPlayedTitle.isEmpty && snapshot.lastPlayedAudiobookID != nil
    }

    private var prominence: Double {
        hasBook ? 1 : 0.45
    }

    private var accentColor: Color {
        themeColor(snapshot.theme.accent)
    }

    var body: some View {
        Group {
            if hasBook {
                Button(intent: PlayLastAudiobookIntent()) {
                    widgetContent
                }
                .buttonStyle(.plain)
            } else {
                widgetContent
            }
        }
    }

    private var widgetContent: some View {
        ZStack {
            ContinueListeningProgressRing(
                progress: snapshot.lastPlayedProgress,
                accent: accentColor,
                track: ContinueListeningPalette.track,
                prominence: prominence
            )

            LockScreenGlassPigView(prominence: prominence)
        }
        .invalidatableContent()
    }
}

// MARK: - Tokens

private enum ContinueListeningPalette {
    static let track = Color.primary
}

private func themeColor(_ rgb: WidgetListeningSnapshot.RGB) -> Color {
    Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
}

// MARK: - Preview

#if DEBUG
struct ContinueListeningWidget_Previews: PreviewProvider {
    static var previews: some View {
        ContinueListeningWidgetView(
            entry: ContinueListeningEntry(
                date: .now,
                snapshot: .init(
                    lastPlayedTitle: "Project Hail Mary",
                    lastPlayedAuthor: "Andy Weir",
                    lastPlayedAudiobookID: UUID().uuidString,
                    lastPlayedProgress: 0.67,
                    todayListenedSeconds: 0,
                    snapshotUpdatedAt: .now,
                    theme: .fallback,
                    hasCoverArtwork: false
                )
            )
        )
        .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}
#endif

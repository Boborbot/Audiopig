//
//  WeeklyListeningWidget.swift
//  AudiopigWidget
//

import WidgetKit
import SwiftUI
import UIKit

// MARK: - Entry

struct WeeklyListeningEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetWeeklyListeningSnapshot.Data
}

// MARK: - Provider

struct WeeklyListeningProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeeklyListeningEntry {
        WeeklyListeningEntry(
            date: .now,
            snapshot: .init(
                days: (0..<7).map { index in
                    WidgetWeeklyListeningSnapshot.DayBucket(
                        dayKey: "day-\(index)",
                        seconds: TimeInterval([0, 1_800, 3_600, 7_200, 5_400, 10_800, 2_700][index])
                    )
                },
                totalSeconds: 32_400
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WeeklyListeningEntry) -> Void) {
        completion(WeeklyListeningEntry(date: .now, snapshot: WidgetWeeklyListeningSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeeklyListeningEntry>) -> Void) {
        let entry = WeeklyListeningEntry(date: .now, snapshot: WidgetWeeklyListeningSnapshot.load())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget

struct WeeklyListeningWidget: Widget {
    let kind = WidgetWeeklyListeningSnapshot.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeeklyListeningProvider()) { entry in
            WeeklyListeningWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WeeklyWidgetPalette.canvas
                }
        }
        .configurationDisplayName("Weekly Listening")
        .description("Your listening hours over the last seven days.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - View

private struct WeeklyListeningWidgetView: View {
    @Environment(\.widgetFamily) private var widgetFamily
    let entry: WeeklyListeningEntry

    private var isMedium: Bool { widgetFamily == .systemMedium }

    private var maxSeconds: TimeInterval {
        max(entry.snapshot.days.map(\.seconds).max() ?? 0, 1)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if isMedium {
                mediumLayout
            } else {
                smallLayout
            }

            WidgetBrandBadge(size: isMedium ? WidgetBrandSpacing.chartBadgeSize : WidgetBrandSpacing.standardBadgeSize)
                .padding(WidgetBrandSpacing.badgeInset)
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: WeeklyWidgetSpacing.sm) {
            Text(WidgetWeeklyListeningSnapshot.formatWeeklyTotal(entry.snapshot.totalSeconds))
                .font(.title3.weight(.bold))
                .foregroundStyle(WeeklyWidgetPalette.primary)
                .padding(.top, WidgetBrandSpacing.standardContentTopPadding)

            HStack(alignment: .bottom, spacing: WeeklyWidgetSpacing.xs) {
                ForEach(Array(entry.snapshot.days.enumerated()), id: \.offset) { _, day in
                    dayColumn(day, barHeight: 48)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(WeeklyWidgetSpacing.md)
    }

    private var mediumLayout: some View {
        HStack(alignment: .bottom, spacing: WeeklyWidgetSpacing.md) {
            weeklyTotalLabel
                .padding(.bottom, 2)

            HStack(alignment: .bottom, spacing: WeeklyWidgetSpacing.sm) {
                ForEach(Array(entry.snapshot.days.enumerated()), id: \.offset) { _, day in
                    dayColumn(day, barHeight: 72)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .padding(WeeklyWidgetSpacing.lg)
        .padding(.top, WidgetBrandSpacing.prominentContentTopPadding)
    }

    private var weeklyTotalLabel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(WidgetWeeklyListeningSnapshot.formatWeeklyTotalHoursMinutes(entry.snapshot.totalSeconds))
                .font(.title3.weight(.bold))
                .foregroundStyle(WeeklyWidgetPalette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text("listened to")
                .font(.caption2)
                .foregroundStyle(WeeklyWidgetPalette.secondary)

            Text("this week")
                .font(.caption2)
                .foregroundStyle(WeeklyWidgetPalette.secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func dayColumn(_ day: WidgetWeeklyListeningSnapshot.DayBucket, barHeight: CGFloat) -> some View {
        VStack(spacing: WeeklyWidgetSpacing.xs) {
            GeometryReader { geometry in
                let height = max(4, geometry.size.height * CGFloat(day.seconds / maxSeconds))
                VStack {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(WeeklyWidgetPalette.coral)
                        .frame(height: height)
                }
            }
            .frame(height: barHeight)

            Text(WidgetWeeklyListeningSnapshot.formatDayBarHours(day.seconds))
                .font(.caption2.weight(.medium))
                .foregroundStyle(WeeklyWidgetPalette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(WidgetWeeklyListeningSnapshot.weekdayLetter(for: day.dayKey))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(WeeklyWidgetPalette.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Tokens

private enum WeeklyWidgetPalette {
    static let coral = Color(red: 0xF1 / 255, green: 0x84 / 255, blue: 0x70 / 255)
    static let primary = Color.primary
    static let secondary = Color.secondary
    static let canvas = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0x14 / 255, green: 0x15 / 255, blue: 0x18 / 255, alpha: 1)
            : UIColor(red: 0xDD / 255, green: 0xD3 / 255, blue: 0xC5 / 255, alpha: 1)
    })
}

private enum WeeklyWidgetSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 6
    static let md: CGFloat = 8
    static let lg: CGFloat = 14
}

// MARK: - Preview

#if DEBUG
struct WeeklyListeningWidget_Previews: PreviewProvider {
    static var previews: some View {
        WeeklyListeningWidgetView(
            entry: WeeklyListeningEntry(
                date: .now,
                snapshot: WidgetWeeklyListeningSnapshot.load()
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}
#endif

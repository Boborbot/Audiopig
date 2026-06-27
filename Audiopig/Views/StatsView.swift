//
//  StatsView.swift
//  Audiopig
//
//  Displays aggregated listening statistics and the achievement icon galleries.
//  Stats are computed by StatsViewModel; icon state is managed by AppIconManager.
//

import SwiftUI

struct StatsView: View {

    private let viewModel: StatsViewModel
    private let appIconManager: AppIconManager

    @State private var showsExpandedSummaryCards = true
    @State private var showsWeeklyPieDetail = false

    private let twoColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    init(viewModel: StatsViewModel, appIconManager: AppIconManager) {
        self.viewModel = viewModel
        self.appIconManager = appIconManager
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    summaryCards
                    achievementsGallery
                    secretAchievementsGallery
                }
                .padding(.vertical, DS.Spacing.sm)
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.canvas.ignoresSafeArea())
            .miniPlayerScrollClearance()
            .navigationTitle("Stats")
            .coralNavigationBanner()
            .onAppear { viewModel.refresh() }
            .sheet(isPresented: $showsWeeklyPieDetail) {
                WeeklyBookPieDetailSheet(
                    slices: viewModel.weeklyBookListeningSlices,
                    totalFormatted: viewModel.weeklyBookListeningTotalFormatted,
                    totalSeconds: viewModel.weeklyBookListeningTotalSeconds,
                    isPartialBreakdown: viewModel.weeklyBookListeningIsPartial
                )
            }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        VStack(spacing: DS.Spacing.sm) {
            HStack {
                Spacer()
                Button(showsExpandedSummaryCards ? "Less" : "More") {
                    withAnimation(DS.Animation.standard) {
                        showsExpandedSummaryCards.toggle()
                    }
                }
                .font(DS.Typography.caption.weight(.semibold))
                .foregroundStyle(DS.Color.coral)
            }

            LazyVGrid(columns: twoColumns, spacing: DS.Spacing.md) {
                StatCard(
                    icon: .bookSpineStack,
                    value: viewModel.totalListenedFormatted,
                    label: "Total Listening"
                )
                StatCard(
                    icon: .system("checkmark.seal.fill"),
                    value: "\(viewModel.finishedBooksCount)",
                    label: "Books Finished"
                )

                if showsExpandedSummaryCards {
                    StatCard(
                        value: viewModel.averageDailyListenedFormatted,
                        label: "Average Daily Listen\nSince first listen"
                    )
                    WeeklyBookPieStatCard(
                        slices: viewModel.weeklyBookListeningSlices,
                        totalFormatted: viewModel.weeklyBookListeningTotalFormatted,
                        totalSeconds: viewModel.weeklyBookListeningTotalSeconds,
                        onTap: { showsWeeklyPieDetail = true }
                    )
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.sm)
    }

    // MARK: - Achievements Gallery

    private var achievementsGallery: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            gallerySectionHeader("Achievements")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(AppIconTier.allCases) { tier in
                        AchievementIconCard(
                            tier: tier,
                            isUnlocked: appIconManager.isUnlocked(tier),
                            isActive: appIconManager.isActive(tier),
                            totalListenedHours: Int(viewModel.totalListenedSeconds / 3_600),
                            onSelect: { appIconManager.applyIcon(tier) }
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }

    // MARK: - Secret Achievements Gallery

    private var secretAchievementsGallery: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            gallerySectionHeader("Secret Achievements")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(SecretAchievement.allCases) { achievement in
                        SecretAchievementCard(
                            achievement: achievement,
                            isUnlocked: appIconManager.isUnlocked(achievement),
                            isActive: appIconManager.isActive(achievement),
                            onSelect: { appIconManager.applyIcon(achievement) }
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }

    private func gallerySectionHeader(_ title: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Text(title)
                .sectionTitle()
            if appIconManager.treatsAllIconsAsUnlocked {
                Text("QA")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Color.coral.opacity(0.85), in: Capsule())
            }
        }
        .padding(.horizontal, DS.Spacing.md)
    }
}

// MARK: - Stat Card

private enum StatCardIcon {
    case bookSpineStack
    case system(String)
}

private enum StatTileTypography {
    static let value = Font.custom("ClashDisplay-Bold", size: 38)
}

private struct StatCard: View {
    var icon: StatCardIcon? = nil
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let icon {
                statIcon(icon)
                    .frame(height: 36)
            }

            Text(value)
                .font(StatTileTypography.value)
                .foregroundStyle(DS.Color.primary)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .padding(.top, icon == nil ? DS.Spacing.sm : DS.Spacing.xs)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .padding(.vertical, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.md)
        .floatingPanel()
    }

    @ViewBuilder
    private func statIcon(_ icon: StatCardIcon) -> some View {
        switch icon {
        case .bookSpineStack:
            BookSpineStackIcon()
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DS.Color.coral)
        }
    }
}

private struct BookSpineStackIcon: View {
    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            bookSpine(width: 7, height: 21, opacity: 0.55, rotation: -5)
            bookSpine(width: 8, height: 27, opacity: 0.88, rotation: 0)
            bookSpine(width: 7, height: 23, opacity: 1.0, rotation: 4)
            bookSpine(width: 6, height: 19, opacity: 0.72, rotation: -3)
        }
        .frame(width: 36, height: 28)
    }

    private func bookSpine(width: CGFloat, height: CGFloat, opacity: Double, rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(DS.Color.coral.opacity(opacity))
            .frame(width: width, height: height)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Weekly Book Pie Stat Card

private struct WeeklyBookPieStatCard: View {
    let slices: [StatsListeningHistory.WeeklyBookSlice]
    let totalFormatted: String
    let totalSeconds: TimeInterval
    var onTap: () -> Void

    private var hasWeeklyListening: Bool {
        totalSeconds > 0
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xs) {
                Group {
                    if hasWeeklyListening, !slices.isEmpty {
                        WeeklyListeningPieChart(slices: slices)
                    } else {
                        Circle()
                            .stroke(DS.Color.separator.opacity(0.55), lineWidth: 10)
                    }
                }
                .frame(width: 72, height: 72)
                .padding(.top, DS.Spacing.sm)

                Text(totalFormatted)
                    .font(StatTileTypography.value)
                    .foregroundStyle(DS.Color.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text("Last Week by Book")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 132)
            .padding(.vertical, DS.Spacing.lg)
            .padding(.horizontal, DS.Spacing.md)
            .floatingPanel()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Weekly Book Pie Detail Sheet

private struct WeeklyBookPieDetailSheet: View {
    let slices: [StatsListeningHistory.WeeklyBookSlice]
    let totalFormatted: String
    let totalSeconds: TimeInterval
    let isPartialBreakdown: Bool

    private var hasWeeklyListening: Bool {
        totalSeconds > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                Text("Last Week by Book")
                    .font(.custom("ClashDisplay-Semibold", size: 22))
                    .foregroundStyle(DS.Color.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: DS.Spacing.md) {
                    Group {
                        if hasWeeklyListening, !slices.isEmpty {
                            WeeklyListeningPieChart(slices: slices)
                        } else {
                            Circle()
                                .stroke(DS.Color.separator.opacity(0.55), lineWidth: 14)
                        }
                    }
                    .frame(width: 220, height: 220)

                    Text(totalFormatted)
                        .font(StatTileTypography.value)
                        .foregroundStyle(DS.Color.primary)

                    Text("Tracked this week")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)

                if slices.isEmpty {
                    Text(
                        hasWeeklyListening
                            ? "Listening time is recorded, but not yet split by book for this week."
                            : "No per-book listening recorded in the last seven days yet."
                    )
                    .font(DS.Typography.listBody)
                    .foregroundStyle(DS.Color.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text("Books")
                            .font(DS.Typography.sectionHeader)
                            .foregroundStyle(DS.Color.primary)

                        VStack(spacing: DS.Spacing.sm) {
                            ForEach(slices) { slice in
                                WeeklyBookPieLegendRow(slice: slice)
                            }
                        }
                        .padding(DS.Spacing.md)
                        .floatingPanel()
                    }
                }

                Text(detailFooter)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass()
        .presentationDetents([.fraction(0.9)])
        .presentationDragIndicator(.visible)
    }

    private var detailFooter: String {
        if isPartialBreakdown {
            return "Unknown is listening time this week that was not recorded per book on this device."
        }
        return "Per-book times come from playback tracked on this device over the last seven days."
    }
}

private struct WeeklyBookPieLegendRow: View {
    let slice: StatsListeningHistory.WeeklyBookSlice

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Circle()
                .fill(statsPieColor(for: slice.paletteIndex))
                .frame(width: 12, height: 12)

            Text(slice.title)
                .font(DS.Typography.listBody)
                .foregroundStyle(DS.Color.primary)
                .lineLimit(2)

            Spacer(minLength: DS.Spacing.sm)

            Text(formatListeningDuration(slice.seconds))
                .font(DS.Typography.controlLabel)
                .foregroundStyle(DS.Color.coral)
                .monospacedDigit()
        }
    }
}

// MARK: - Weekly Listening Pie Chart

private struct WeeklyListeningPieChart: View {
    let slices: [StatsListeningHistory.WeeklyBookSlice]

    private var segments: [PieSegment] {
        let total = slices.reduce(0.0) { $0 + $1.seconds }
        guard total > 0 else { return [] }

        let gap = slices.count > 1 ? 1.5 : 0.0
        let usableDegrees = 360 - gap * Double(slices.count)
        var start = -90.0 + gap / 2

        return slices.map { slice in
            let sweep = usableDegrees * slice.seconds / total
            let segment = PieSegment(
                startDegrees: start,
                endDegrees: start + sweep,
                color: statsPieColor(for: slice.paletteIndex)
            )
            start += sweep + gap
            return segment
        }
    }

    var body: some View {
        ZStack {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                DonutSliceShape(
                    startDegrees: segment.startDegrees,
                    endDegrees: segment.endDegrees,
                    innerRadiusRatio: 0.58
                )
                .fill(segment.color)
            }
        }
    }
}

private struct PieSegment {
    let startDegrees: Double
    let endDegrees: Double
    let color: Color
}

private struct DonutSliceShape: Shape {
    let startDegrees: Double
    let endDegrees: Double
    let innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio
        let center = CGPoint(x: rect.midX, y: rect.midY)

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(startDegrees),
            endAngle: .degrees(endDegrees),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(endDegrees),
            endAngle: .degrees(startDegrees),
            clockwise: true
        )
        path.closeSubpath()
        return path
    }
}

private func statsPieColor(for index: Int) -> Color {
    if index == StatsChartPalette.unknownPaletteIndex {
        let grey = StatsChartPalette.unknownColor
        return Color(red: grey.red, green: grey.green, blue: grey.blue)
    }
    let palette = StatsChartPalette.bookColors
    guard !palette.isEmpty else { return DS.Color.secondary }
    let safeIndex = min(max(index, 0), palette.count - 1)
    let rgb = palette[safeIndex]
    return Color(red: rgb.red, green: rgb.green, blue: rgb.blue)
}

private func formatListeningDuration(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    let h = total / 3600
    let m = (total % 3600) / 60
    if h > 0 && m > 0 { return "\(h) h \(m) m" }
    if h > 0 { return "\(h) h" }
    if m > 0 { return "\(m) min" }
    if total > 0 { return "< 1 min" }
    return "0 min"
}

// MARK: - Achievement Icon Card

private struct AchievementIconCard: View {
    let tier: AppIconTier
    let isUnlocked: Bool
    let isActive: Bool
    let totalListenedHours: Int
    let onSelect: () -> Void

    private var progress: Double {
        guard !isUnlocked, tier.requiredHours > 0 else { return 1 }
        return min(1, Double(totalListenedHours) / Double(tier.requiredHours))
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            AppIconGalleryThumbnail(
                galleryImageName: tier.galleryImageName,
                isUnlocked: isUnlocked,
                style: .achievement(progress: progress)
            )

            Text(tier.label)
                .font(.custom("ClashDisplay-Semibold", size: 14))
                .foregroundStyle(isUnlocked ? DS.Color.primary : DS.Color.tertiary)

            Text(tier.gallerySubtitle)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)

            statusLabel
        }
        .frame(width: 100)
        .padding(DS.Spacing.md)
        .floatingPanel()
        .opacity(isUnlocked ? 1 : 0.85)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isUnlocked, !isActive else { return }
            onSelect()
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if isActive {
            Text("Active")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(DS.Color.coral, in: Capsule())
        } else if isUnlocked {
            Text("Tap to use")
                .font(.caption2)
                .foregroundStyle(DS.Color.coral)
        } else {
            let hoursLeft = max(0, tier.requiredHours - totalListenedHours)
            Text("\(hoursLeft)h to go")
                .font(.caption2)
                .foregroundStyle(DS.Color.tertiary)
        }
    }
}

// MARK: - Secret Achievement Card

private struct SecretAchievementCard: View {
    let achievement: SecretAchievement
    let isUnlocked: Bool
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            AppIconGalleryThumbnail(
                galleryImageName: achievement.galleryImageName,
                isUnlocked: isUnlocked,
                style: .secret
            )

            Text(isUnlocked ? achievement.label : "???")
                .font(.custom("ClashDisplay-Semibold", size: 14))
                .foregroundStyle(isUnlocked ? DS.Color.primary : DS.Color.tertiary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 34)

            Text("Secret")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)

            statusLabel
        }
        .frame(width: 100)
        .padding(DS.Spacing.md)
        .floatingPanel()
        .opacity(isUnlocked ? 1 : 0.85)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isUnlocked, !isActive else { return }
            onSelect()
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        if isActive {
            Text("Active")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, 3)
                .background(DS.Color.coral, in: Capsule())
        } else if isUnlocked {
            Text("Tap to use")
                .font(.caption2)
                .foregroundStyle(DS.Color.coral)
        } else {
            Text("Locked")
                .font(.caption2)
                .foregroundStyle(DS.Color.tertiary)
        }
    }
}

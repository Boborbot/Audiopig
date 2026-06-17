//
//  StatsView.swift
//  Audiopig
//
//  Displays aggregated listening statistics and the achievement icon galleries.
//  Stats are computed by StatsViewModel; icon state is managed by AppIconManager.
//

import SwiftUI

struct StatsView: View {

    @State private var viewModel: StatsViewModel
    private let appIconManager: AppIconManager

    private let twoColumns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    init(viewModel: StatsViewModel, appIconManager: AppIconManager) {
        _viewModel = State(initialValue: viewModel)
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
            .navigationTitle("Stats")
            .coralNavigationBanner()
            .onAppear { viewModel.refresh() }
        }
    }

    // MARK: - Summary Cards

    private var summaryCards: some View {
        LazyVGrid(columns: twoColumns, spacing: DS.Spacing.md) {
            StatCard(
                icon: "headphones",
                value: viewModel.totalListenedFormatted,
                label: "Total Listening"
            )
            StatCard(
                icon: "checkmark.seal.fill",
                value: "\(viewModel.finishedBooksCount)",
                label: "Books Finished"
            )
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
                            totalListenedHours: Int(viewModel.finishedListenedSeconds / 3_600),
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

private struct StatCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(DS.Color.coral)
                .frame(height: 36)

            Text(value)
                .font(.custom("ClashDisplay-Bold", size: 30))
                .foregroundStyle(DS.Color.primary)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
                .padding(.top, DS.Spacing.xs)

            Text(label)
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.md)
        .floatingPanel()
    }
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

//
//  StatsView.swift
//  Audiopig
//
//  Displays aggregated listening statistics and the unlockable icon gallery.
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
                    hourClubGallery
                    secretIconGallery
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

    // MARK: - Hour Club Gallery

    private var hourClubGallery: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("Hour Club")
                .sectionTitle()
                .padding(.horizontal, DS.Spacing.md)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DS.Spacing.md) {
                    ForEach(AppIconTier.allCases) { tier in
                        IconTierCard(
                            tier: tier,
                            isUnlocked: appIconManager.isUnlocked(tier),
                            isActive: appIconManager.isActive(tier),
                            totalListenedHours: Int(viewModel.finishedListenedSeconds / 3_600),
                            onApply: { appIconManager.applyIcon(tier) }
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
            }
        }
    }

    // MARK: - Secret Icon Gallery

    @ViewBuilder
    private var secretIconGallery: some View {
        let unlockedSecrets = appIconManager.unlockedSecrets
        if !unlockedSecrets.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text("Secret Icons")
                    .sectionTitle()
                    .padding(.horizontal, DS.Spacing.md)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(unlockedSecrets) { achievement in
                            SecretIconCard(
                                achievement: achievement,
                                isActive: appIconManager.isActive(achievement),
                                onApply: { appIconManager.applyIcon(achievement) }
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
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

// MARK: - Icon Tier Card

private struct IconTierCard: View {
    let tier: AppIconTier
    let isUnlocked: Bool
    let isActive: Bool
    let totalListenedHours: Int
    let onApply: () -> Void

    private var progress: Double {
        guard !isUnlocked else { return 1 }
        return min(1, Double(totalListenedHours) / Double(tier.requiredHours))
    }

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(DS.Color.coral.opacity(0.15), lineWidth: 3)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DS.Color.coral, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                    .animation(DS.Animation.standard, value: progress)

                Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isUnlocked ? DS.Color.coral : DS.Color.tertiary)
            }

            Text(tier.label)
                .font(.custom("ClashDisplay-Semibold", size: 14))
                .foregroundStyle(isUnlocked ? DS.Color.primary : DS.Color.tertiary)

            Text("\(tier.requiredHours)h")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)

            if isUnlocked {
                if isActive {
                    Text("Active")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(DS.Color.coral, in: Capsule())
                } else {
                    Button("Apply") { onApply() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.Color.coral)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(
                            Capsule().strokeBorder(DS.Color.coral.opacity(0.5), lineWidth: 1)
                        )
                }
            } else {
                let hoursLeft = max(0, tier.requiredHours - totalListenedHours)
                Text("\(hoursLeft)h to go")
                    .font(.caption2)
                    .foregroundStyle(DS.Color.tertiary)
            }
        }
        .frame(width: 100)
        .padding(DS.Spacing.md)
        .floatingPanel()
        .opacity(isUnlocked ? 1 : 0.7)
    }
}

// MARK: - Secret Icon Card

private struct SecretIconCard: View {
    let achievement: SecretAchievement
    let isActive: Bool
    let onApply: () -> Void

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DS.Color.coral.opacity(0.25), DS.Color.coral.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                Image(systemName: "sparkles")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(DS.Color.coral)
            }

            Text(achievement.label)
                .font(.custom("ClashDisplay-Semibold", size: 14))
                .foregroundStyle(DS.Color.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(minHeight: 34)

            Text("Secret")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)

            if isActive {
                Text("Active")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(DS.Color.coral, in: Capsule())
            } else {
                Button("Apply") { onApply() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.Color.coral)
                    .padding(.horizontal, DS.Spacing.sm)
                    .padding(.vertical, 3)
                    .background(
                        Capsule().strokeBorder(DS.Color.coral.opacity(0.5), lineWidth: 1)
                    )
            }
        }
        .frame(width: 100)
        .padding(DS.Spacing.md)
        .floatingPanel()
    }
}

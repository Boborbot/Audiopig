//
//  StatsView.swift
//  Audiopig
//
//  Displays aggregated listening statistics: total listened time and
//  finished books count. Stats are computed by StatsViewModel from SwiftData.
//

import SwiftUI

struct StatsView: View {

    @State private var viewModel: StatsViewModel

    private let columns = [
        GridItem(.flexible(), spacing: DS.Spacing.md),
        GridItem(.flexible(), spacing: DS.Spacing.md)
    ]

    init(viewModel: StatsViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    LazyVGrid(columns: columns, spacing: DS.Spacing.md) {
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
                .padding(.bottom, DS.Spacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(DS.Color.canvas.ignoresSafeArea())
            .navigationTitle("Stats")
            .coralNavigationBanner()
            .onAppear { viewModel.refresh() }
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
                .font(DS.ClashDisplay.font(.bold, size: 30))
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

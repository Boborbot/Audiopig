//
//  TipJarSection.swift
//  Audiopig
//

import SwiftUI

struct TipJarSection: View {
    @Bindable var viewModel: SettingsMonetizationViewModel

    var body: some View {
        Section {
            if let tier = viewModel.thankYouTier {
                thankYouCard(for: tier)
            } else {
                ForEach(TipTier.allCases) { tier in
                    Button {
                        Task { await viewModel.purchaseTip(tier) }
                    } label: {
                        HStack {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tier.title)
                                        .font(DS.Typography.listTitle)
                                    Text(tier.subtitle)
                                        .font(DS.Typography.caption)
                                        .foregroundStyle(DS.Color.tertiary)
                                }
                            } icon: {
                                Image(systemName: tier.systemImage)
                                    .foregroundStyle(DS.Color.coral)
                            }
                            Spacer()
                            if viewModel.isProcessing {
                                ProgressView()
                                    .scaleEffect(0.85)
                            } else if let price = viewModel.displayPrice(for: tier) {
                                Text(price)
                                    .font(DS.Typography.listBody)
                                    .foregroundStyle(DS.Color.secondary)
                            }
                        }
                    }
                    .disabled(viewModel.isProcessing)
                }
            }

            if let errorMessage = viewModel.errorMessage, viewModel.thankYouTier == nil {
                Text(errorMessage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Feed a Student")
                .sectionTitle()
        } footer: {
            Text("Audiopig is a student-built indie app. Tips are optional and go toward keeping development going — they don't unlock features.")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.tertiary)
        }
    }

    private func thankYouCard(for tier: TipTier) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label("Thank you!", systemImage: "heart.fill")
                .font(DS.Typography.listTitle)
                .foregroundStyle(DS.Color.coral)

            Text("Your \(tier.title.lowercased()) tip means a lot. Happy listening!")
                .font(DS.Typography.listBody)
                .foregroundStyle(DS.Color.secondary)

            Button("Done") {
                viewModel.dismissThankYou()
            }
            .font(DS.Typography.listBody)
            .foregroundStyle(DS.Color.coral)
            .padding(.top, DS.Spacing.xs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DS.Spacing.xs)
    }
}

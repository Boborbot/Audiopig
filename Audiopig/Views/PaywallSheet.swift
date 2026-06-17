//
//  PaywallSheet.swift
//  Audiopig
//

import SwiftUI

struct PaywallSheet: View {
    @Bindable var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    var onUnlocked: (() -> Void)?

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            header
            featureCopy
            primaryButton
            secondaryActions
            if let disclosure = viewModel.renewalDisclosure {
                Text(disclosure)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Color.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.md)
            }
            LegalDocumentLinks(alignment: .center)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, DS.Spacing.xl)
        .padding(.bottom, DS.Spacing.lg)
        .padding(.horizontal, DS.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .task { await viewModel.onAppear() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: DS.Spacing.sm) {
            Image(systemName: "waveform.and.magnifyingglass")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(DS.Color.coral)
            Text(viewModel.headline)
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.primary)
                .multilineTextAlignment(.center)
        }
    }

    private var featureCopy: some View {
        Text(viewModel.bodyCopy)
            .font(DS.Typography.listBody)
            .foregroundStyle(DS.Color.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, DS.Spacing.sm)
    }

    private var primaryButton: some View {
        Button {
            Task {
                let unlocked = await viewModel.purchasePlus()
                if unlocked {
                    onUnlocked?()
                    dismiss()
                }
            }
        } label: {
            Group {
                if viewModel.isPurchasing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(viewModel.primaryCTATitle)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(DS.ButtonStyle.primary(isDisabled: viewModel.isPurchasing))
        .disabled(viewModel.isPurchasing)
    }

    private var secondaryActions: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(DS.Typography.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button("Restore Purchases") {
                Task {
                    let restored = await viewModel.restorePurchases()
                    if restored {
                        onUnlocked?()
                        dismiss()
                    }
                }
            }
            .font(DS.Typography.listBody)
            .foregroundStyle(DS.Color.coral)
            .disabled(viewModel.isPurchasing)

            Button("Not now") {
                dismiss()
            }
            .font(DS.Typography.listBody)
            .foregroundStyle(DS.Color.secondary)
            .disabled(viewModel.isPurchasing)
        }
    }
}

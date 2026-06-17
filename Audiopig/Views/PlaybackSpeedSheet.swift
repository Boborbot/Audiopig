//
//  PlaybackSpeedSheet.swift
//  Audiopig
//

import SwiftUI

struct PlaybackSpeedSheet: View {
    let viewModel: PlayerViewModel

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            header

            sliderRow
                .padding(.horizontal, DS.Spacing.md)

            presetRow
                .padding(.horizontal, DS.Spacing.md)
        }
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass()
        .presentationDetents([.fraction(0.33)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Playback Speed")
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.primary)

            Spacer()

            Text(viewModel.speedLabel)
                .font(DS.Typography.controlLabel.monospacedDigit())
                .foregroundStyle(DS.Color.coral)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    // MARK: - Slider Row

    private var sliderRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            stepButton(systemName: "minus") {
                viewModel.adjustSpeed(by: -PlayerViewModel.playbackSpeedStep)
            }
            .accessibilityLabel("Decrease speed")

            Slider(
                value: sliderBinding,
                in: Double(PlayerViewModel.minPlaybackSpeed)...Double(PlayerViewModel.maxPlaybackSpeed),
                step: Double(PlayerViewModel.playbackSpeedStep)
            )
            .tint(DS.Color.coral)
            .accessibilityLabel("Playback speed")
            .accessibilityValue(viewModel.speedLabel)

            stepButton(systemName: "plus") {
                viewModel.adjustSpeed(by: PlayerViewModel.playbackSpeedStep)
            }
            .accessibilityLabel("Increase speed")
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.playbackSpeed) },
            set: { viewModel.setSpeed(Float($0)) }
        )
    }

    // MARK: - Preset Row

    private var presetRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(viewModel.speedPresets, id: \.self) { preset in
                Button {
                    viewModel.setSpeed(preset)
                } label: {
                    Text(PlayerViewModel.formatSpeedLabel(preset))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DS.ButtonStyle.pill(isActive: viewModel.isSpeedPresetActive(preset)))
                .accessibilityAddTraits(viewModel.isSpeedPresetActive(preset) ? .isSelected : [])
            }
        }
    }

    // MARK: - Step Button

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(DS.Color.primary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color(UIColor.secondarySystemBackground)))
        }
        .buttonStyle(DS.ButtonStyle.transport)
    }
}

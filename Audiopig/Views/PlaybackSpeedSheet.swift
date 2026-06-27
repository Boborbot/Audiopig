//
//  PlaybackSpeedSheet.swift
//  Audiopig
//

import SwiftUI

struct PlaybackSpeedSheet: View {
    let viewModel: PlayerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Spacing.md) {
                sectionHeader(title: "Playback Speed", value: viewModel.speedLabel)

                speedSliderRow
                    .padding(.horizontal, DS.Spacing.md)

                speedPresetRow
                    .padding(.horizontal, DS.Spacing.md)
            }
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass()
        .presentationDetents([.fraction(0.38)])
        .presentationDragIndicator(.visible)
    }

    private func sectionHeader(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.primary)

            Spacer()

            Text(value)
                .font(DS.Typography.controlLabel)
                .foregroundStyle(DS.Color.coral)
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private var speedSliderRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            speedStepButton(systemName: "minus") {
                viewModel.adjustSpeed(by: -WatchSpeedRange.step)
            }

            Slider(
                value: speedSliderBinding,
                in: Double(WatchSpeedRange.min)...Double(WatchSpeedRange.max),
                step: Double(WatchSpeedRange.step)
            )
            .tint(DS.Color.coral)

            speedStepButton(systemName: "plus") {
                viewModel.adjustSpeed(by: WatchSpeedRange.step)
            }
        }
    }

    private var speedPresetRow: some View {
        HStack(spacing: DS.Spacing.sm) {
            ForEach(viewModel.speedPresets, id: \.self) { preset in
                Button {
                    viewModel.setSpeed(preset)
                } label: {
                    Text(WatchSpeedRange.formatLabel(preset))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DS.ButtonStyle.pill(isActive: viewModel.isSpeedPresetActive(preset)))
            }
        }
    }

    private var speedSliderBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.playbackSpeed) },
            set: { viewModel.setSpeed(Float($0)) }
        )
    }

    private func speedStepButton(systemName: String, action: @escaping () -> Void) -> some View {
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

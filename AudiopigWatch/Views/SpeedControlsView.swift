//
//  SpeedControlsView.swift
//  AudiopigWatch
//

import SwiftUI

struct SpeedControlsView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    let isActive: Bool

    init(viewModel: WatchPlayerViewModel, isActive: Bool) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.isActive = isActive
    }

    var body: some View {
        VStack(spacing: WDS.Spacing.md) {
            Stepper(
                value: speedBinding,
                in: Double(WatchSpeedRange.min)...Double(WatchSpeedRange.max),
                step: Double(WatchSpeedRange.step)
            ) {
                Text(viewModel.speedLabel)
                    .font(.title2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(WDS.Color.coral)
            }
            .tint(WDS.Color.coral)
            .disabled(!isActive)
            .accessibilityLabel("Playback speed")
            .accessibilityValue(viewModel.speedLabel)

            presetRow
        }
        .padding(.horizontal, WDS.Spacing.sm)
    }

    private var speedBinding: Binding<Double> {
        Binding(
            get: { Double(viewModel.speedDraft) },
            set: { newValue in
                viewModel.speedDraft = WatchSpeedRange.normalized(Float(newValue))
                viewModel.applySpeedDraft()
            }
        )
    }

    private var presetRow: some View {
        HStack(spacing: WDS.Spacing.xs) {
            ForEach(viewModel.speedPresets, id: \.self) { preset in
                Button {
                    viewModel.selectSpeedPreset(preset)
                } label: {
                    Text(presetLabel(preset))
                        .font(.caption2.monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(
                            viewModel.speedDraft == preset
                                ? WDS.Color.coral.opacity(0.25)
                                : Color.gray.opacity(0.2),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func presetLabel(_ speed: Float) -> String {
        speed.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(speed))"
            : String(format: "%.2g", speed)
    }
}

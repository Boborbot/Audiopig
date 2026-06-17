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

    @State private var lastDetentSpeed: Float = 1.0

    var body: some View {
        VStack(spacing: WDS.Spacing.md) {
            Text(viewModel.speedLabel)
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(WDS.Color.coral)

            Slider(
                value: Binding(
                    get: { Double(viewModel.speedDraft) },
                    set: { viewModel.speedDraft = Float($0) }
                ),
                in: Double(WatchSpeedRange.min)...Double(WatchSpeedRange.max),
                step: Double(WatchSpeedRange.step)
            )
            .tint(WDS.Color.coral)

            presetRow
        }
        .padding(.horizontal, WDS.Spacing.sm)
        .focusable(isActive)
        .digitalCrownRotation(
            $viewModel.speedDraft,
            from: WatchSpeedRange.min,
            through: WatchSpeedRange.max,
            by: WatchSpeedRange.crownStep,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: viewModel.speedDraft) { _, newValue in
            guard isActive else {
                lastDetentSpeed = normalizedSpeed(newValue)
                return
            }
            let normalized = normalizedSpeed(newValue)
            if normalized != lastDetentSpeed {
                lastDetentSpeed = normalized
                viewModel.speedDraft = normalized
                viewModel.applySpeedDraft()
            }
        }
        .onChange(of: isActive) { _, active in
            if active {
                lastDetentSpeed = viewModel.speedDraft
            }
        }
        .onAppear {
            lastDetentSpeed = viewModel.speedDraft
        }
    }

    private var presetRow: some View {
        HStack(spacing: WDS.Spacing.xs) {
            ForEach(viewModel.speedPresets, id: \.self) { preset in
                Button {
                    viewModel.selectSpeedPreset(preset)
                    lastDetentSpeed = preset
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

    private func normalizedSpeed(_ speed: Float) -> Float {
        let stepped = (speed / WatchSpeedRange.step).rounded() * WatchSpeedRange.step
        return min(WatchSpeedRange.max, max(WatchSpeedRange.min, stepped))
    }
}

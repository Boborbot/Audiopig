//
//  WatchVolumeCrownModifier.swift
//  AudiopigWatch
//

import SwiftUI

/// Pager-owned Digital Crown input for transport-page volume.
struct WatchVolumeCrownModifier: ViewModifier {
    @ObservedObject var viewModel: WatchPlayerViewModel
    let isActive: Bool

    @State private var crownValue: Float = WatchVolumeRange.crownValue(for: 0.5)
    @State private var lastAppliedVolume: Float = 0.5

    func body(content: Content) -> some View {
        content
            .overlay {
                if isActive, viewModel.showVolumeOverlay {
                    volumeOverlay
                }
            }
            .focusable(isActive)
            .watchDigitalCrownLow(
                isActive: isActive,
                value: $crownValue,
                from: WatchVolumeRange.crownMinimum,
                through: WatchVolumeRange.crownMaximum,
                by: WatchVolumeRange.crownStep,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            .onChange(of: crownValue) { _, newValue in
                applyCrownValue(newValue)
            }
            .onChange(of: viewModel.volumeDraft) { _, newValue in
                guard !viewModel.isVolumeAdjustmentActive else { return }
                syncCrownFromViewModel(volume: newValue)
            }
            .onAppear {
                syncCrownFromViewModel(volume: viewModel.volumeDraft)
            }
    }

    private func applyCrownValue(_ newValue: Float) {
        let normalized = WatchVolumeRange.volume(fromCrownValue: newValue)
        guard isActive, normalized != lastAppliedVolume else { return }

        lastAppliedVolume = normalized
        viewModel.volumeDraft = normalized
        viewModel.applyVolumeDraft()
    }

    private func syncCrownFromViewModel(volume: Float) {
        let normalized = WatchVolumeRange.normalized(volume)
        lastAppliedVolume = normalized
        let value = WatchVolumeRange.crownValue(for: normalized)
        if abs(crownValue - value) > WatchVolumeRange.tolerance {
            crownValue = value
        }
    }

    private var volumeOverlay: some View {
        Image(systemName: volumeSymbol)
            .font(.title)
            .foregroundStyle(.white)
            .padding()
            .background(.black.opacity(0.55), in: Circle())
            .transition(.opacity)
            .allowsHitTesting(false)
    }

    private var volumeSymbol: String {
        let level = lastAppliedVolume
        if level <= 0.01 { return "speaker.slash.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

extension View {
    func watchVolumeCrown(viewModel: WatchPlayerViewModel, isActive: Bool) -> some View {
        modifier(WatchVolumeCrownModifier(viewModel: viewModel, isActive: isActive))
    }
}

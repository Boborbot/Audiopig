//
//  WatchVolumeCrownModifier.swift
//  AudiopigWatch
//

import SwiftUI

/// Captures Digital Crown input for volume on transport pages inside a vertical `TabView`.
struct WatchVolumeCrownModifier: ViewModifier {
    @ObservedObject var viewModel: WatchPlayerViewModel
    let isActive: Bool

    @FocusState private var crownFocused: Bool
    @State private var crownVolume: Float = 0.5
    @State private var lastDetentVolume: Float = 0.5

    func body(content: Content) -> some View {
        content
            .overlay {
                if viewModel.showVolumeOverlay {
                    volumeOverlay
                }
            }
            .focusable(isActive)
            .focused($crownFocused)
            .digitalCrownRotation(
                $crownVolume,
                from: 0,
                through: 1,
                by: WatchVolumeRange.crownStep,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            .onChange(of: crownVolume) { _, newValue in
                guard isActive else {
                    lastDetentVolume = WatchVolumeRange.normalized(newValue)
                    return
                }
                let normalized = WatchVolumeRange.normalized(newValue)
                if normalized != crownVolume {
                    crownVolume = normalized
                }
                guard normalized != lastDetentVolume else { return }
                lastDetentVolume = normalized
                viewModel.volumeDraft = normalized
                viewModel.applyVolumeDraft()
            }
            .onChange(of: viewModel.volumeDraft) { _, newValue in
                guard !viewModel.isVolumeAdjustmentActive else { return }
                let normalized = WatchVolumeRange.normalized(newValue)
                lastDetentVolume = normalized
                if abs(crownVolume - normalized) > WatchVolumeRange.tolerance {
                    crownVolume = normalized
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    claimCrownFocus()
                } else {
                    crownFocused = false
                }
            }
            .onAppear {
                syncCrownFromViewModel()
                if isActive {
                    claimCrownFocus()
                }
            }
    }

    private func claimCrownFocus() {
        syncCrownFromViewModel()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard isActive else { return }
            crownFocused = true
        }
    }

    private func syncCrownFromViewModel() {
        let normalized = WatchVolumeRange.normalized(viewModel.volumeDraft)
        crownVolume = normalized
        lastDetentVolume = normalized
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
        let level = crownVolume
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

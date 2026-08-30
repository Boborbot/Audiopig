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
    @State private var crownAxis: Float = WatchVolumeRange.crownAxis(for: 0.5)
    @State private var lastCrownAxis: Float = WatchVolumeRange.crownAxis(for: 0.5)
    @State private var lastAppliedVolume: Float = 0.5
    @State private var preActivationScroll: Float = 0
    @State private var isCrownArmed = false
    @State private var crownIdleTask: Task<Void, Never>?

    func body(content: Content) -> some View {
        content
            .overlay {
                if viewModel.showVolumeOverlay {
                    volumeOverlay
                }
            }
            .focusable(isActive)
            .focused($crownFocused)
            .watchDigitalCrownLow(
                isActive: isActive,
                value: $crownAxis,
                from: 1,
                through: 0,
                by: WatchVolumeRange.crownStep,
                isContinuous: false,
                isHapticFeedbackEnabled: false
            )
            .onChange(of: crownAxis) { _, newAxis in
                handleCrownAxisChange(newAxis)
            }
            .onChange(of: viewModel.volumeDraft) { _, newValue in
                guard !viewModel.isVolumeAdjustmentActive else { return }
                syncCrownFromViewModel(volume: newValue)
            }
            .onChange(of: isActive) { _, active in
                if active {
                    resetCrownGestureState()
                    claimCrownFocus()
                } else {
                    crownFocused = false
                    resetCrownGestureState()
                }
            }
            .onAppear {
                resetCrownGestureState()
                if isActive {
                    claimCrownFocus()
                }
            }
            .onDisappear {
                crownIdleTask?.cancel()
            }
    }

    private func handleCrownAxisChange(_ newAxis: Float) {
        guard isActive else {
            lastCrownAxis = newAxis
            lastAppliedVolume = WatchVolumeRange.volume(fromCrownAxis: newAxis)
            return
        }

        if !isCrownArmed {
            let scrollDelta = abs(newAxis - lastCrownAxis)
            lastCrownAxis = newAxis
            preActivationScroll += scrollDelta

            if preActivationScroll < WatchVolumeRange.crownActivationThreshold {
                let lockedAxis = WatchVolumeRange.crownAxis(for: lastAppliedVolume)
                if abs(crownAxis - lockedAxis) > WatchVolumeRange.tolerance {
                    crownAxis = lockedAxis
                }
                lastCrownAxis = lockedAxis
                return
            }

            isCrownArmed = true
            preActivationScroll = 0
        } else {
            lastCrownAxis = newAxis
        }

        let normalized = WatchVolumeRange.volume(fromCrownAxis: newAxis)
        guard normalized != lastAppliedVolume else {
            scheduleCrownDisarm()
            return
        }

        lastAppliedVolume = normalized
        viewModel.volumeDraft = normalized
        viewModel.applyVolumeDraft()
        scheduleCrownDisarm()
    }

    private func scheduleCrownDisarm() {
        crownIdleTask?.cancel()
        crownIdleTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            isCrownArmed = false
            preActivationScroll = 0
            syncCrownFromViewModel(volume: viewModel.volumeDraft)
        }
    }

    private func claimCrownFocus() {
        syncCrownFromViewModel(volume: viewModel.volumeDraft)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard isActive else { return }
            crownFocused = true
        }
    }

    private func resetCrownGestureState() {
        crownIdleTask?.cancel()
        isCrownArmed = false
        preActivationScroll = 0
        syncCrownFromViewModel(volume: viewModel.volumeDraft)
    }

    private func syncCrownFromViewModel(volume: Float) {
        let normalized = WatchVolumeRange.normalized(volume)
        lastAppliedVolume = normalized
        let axis = WatchVolumeRange.crownAxis(for: normalized)
        lastCrownAxis = axis
        if abs(crownAxis - axis) > WatchVolumeRange.tolerance {
            crownAxis = axis
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

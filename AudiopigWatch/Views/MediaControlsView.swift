//
//  MediaControlsView.swift
//  AudiopigWatch
//

import SwiftUI

struct MediaControlsView: View {
    @ObservedObject var viewModel: WatchPlayerViewModel
    var isActive: Bool = true

    init(viewModel: WatchPlayerViewModel, isActive: Bool = true) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.isActive = isActive
    }

    @State private var tapCount = 0
    @State private var tapTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VStack(spacing: WDS.Spacing.sm) {
                artworkTapZone
                lullSection
                titleBlock
                timebar
                transportRow
                connectionStatus
            }
            .padding(.horizontal, WDS.Spacing.sm)

            if viewModel.showVolumeOverlay {
                volumeOverlay
            }
        }
        .focusable(isActive)
        .digitalCrownRotation(
            $viewModel.volumeDraft,
            from: 0,
            through: 1,
            by: 0.02,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onChange(of: viewModel.volumeDraft) { _, _ in
            guard isActive else { return }
            viewModel.applyVolumeDraft()
        }
        .task {
            await viewModel.refresh()
        }
    }

    private var artworkTapZone: some View {
        Color.clear
            .frame(height: 56)
            .contentShape(Rectangle())
            .onTapGesture {
                guard viewModel.artworkSkipGesturesEnabled else { return }
                tapCount += 1
                tapTask?.cancel()
                tapTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    let count = tapCount
                    tapCount = 0
                    switch count {
                    case 2:
                        viewModel.handleArtworkDoubleTap()
                    case 3:
                        viewModel.handleArtworkTripleTap()
                    default:
                        break
                    }
                }
            }
            .accessibilityLabel("Artwork gestures")
            .accessibilityHint(
                viewModel.artworkSkipGesturesEnabled
                    ? "Double-tap skip forward, triple-tap skip back"
                    : "Disabled in settings"
            )
    }

    @ViewBuilder
    private var lullSection: some View {
        if viewModel.showsRemoteLullDetection {
            switch viewModel.lullState {
            case .idle:
                Button {
                    viewModel.analyzeLulls()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform.and.magnifyingglass")
                        Text("Find Break")
                    }
                    .font(.caption2.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(WDS.Color.coral.opacity(0.15), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.isActive)

            case .analyzing:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Analyzing…")
                        .font(.caption2)
                }
                .frame(maxWidth: .infinity)

            case .result(let lull):
                VStack(spacing: 4) {
                    Button {
                        viewModel.seekToLull(lull)
                    } label: {
                        Text(viewModel.lullLabel(for: lull))
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(WDS.Color.coral.opacity(0.25), in: Capsule())
                    }
                    .buttonStyle(.plain)

                    Button("Cancel") {
                        viewModel.cancelLullAnalysis()
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                }

            case .empty:
                VStack(spacing: 4) {
                    Text("No break found")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Button("Try Again") {
                        viewModel.retryLullAnalysis()
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                }

            case .unavailable(let message):
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var titleBlock: some View {
        VStack(spacing: WDS.Spacing.xs) {
            if viewModel.snapshot.bookID == nil {
                Text("No book loaded")
                    .font(WDS.Typography.title)
                    .foregroundStyle(.secondary)
            } else {
                Text(viewModel.snapshot.title)
                    .font(WDS.Typography.title)
                    .lineLimit(1)
                Text(viewModel.snapshot.chapterTitle)
                    .font(WDS.Typography.chapter)
                    .foregroundStyle(WDS.Color.coral)
                    .lineLimit(1)
            }
        }
    }

    private var timebar: some View {
        VStack(spacing: WDS.Spacing.xs) {
            ProgressView(value: viewModel.timebarProgressDisplay)
                .tint(WDS.Color.coral)
            HStack {
                Text(WatchTimeFormat.format(viewModel.timebarElapsedDisplay))
                    .font(WDS.Typography.time)
                Spacer()
                Text("-\(WatchTimeFormat.format(viewModel.timebarRemainingDisplay))")
                    .font(WDS.Typography.time)
            }
            .foregroundStyle(.secondary)
        }
    }

    private var transportRow: some View {
        HStack {
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: skipBackwardSymbol)
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.togglePlayPause()
            } label: {
                Group {
                    if viewModel.displayState == .loading {
                        ProgressView()
                    } else {
                        Image(systemName: playPauseSymbol)
                            .font(.title2.weight(.semibold))
                    }
                }
                .frame(width: 52, height: 52)
            }
            .buttonStyle(.plain)

            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: skipForwardSymbol)
                    .font(.title3)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        if let message = viewModel.connectionMessage {
            Text(message)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
    }

    private var volumeOverlay: some View {
        Image(systemName: volumeSymbol)
            .font(.title)
            .foregroundStyle(.white)
            .padding()
            .background(.black.opacity(0.55), in: Circle())
            .transition(.opacity)
    }

    private var volumeSymbol: String {
        let level = viewModel.volumeDraft
        if level <= 0.01 { return "speaker.slash.fill" }
        if level < 0.34 { return "speaker.wave.1.fill" }
        if level < 0.67 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private var playPauseSymbol: String {
        viewModel.displayState == .playing ? "pause.fill" : "play.fill"
    }

    private var skipBackwardSymbol: String {
        intervalSymbol(prefix: "gobackward", seconds: viewModel.skipBackwardInterval)
    }

    private var skipForwardSymbol: String {
        intervalSymbol(prefix: "goforward", seconds: viewModel.skipForwardInterval)
    }

    private func intervalSymbol(prefix: String, seconds: Int) -> String {
        let supported = [5, 10, 15, 30, 45, 60, 75, 90]
        if supported.contains(seconds) {
            return "\(prefix).\(seconds)"
        }
        return prefix
    }
}

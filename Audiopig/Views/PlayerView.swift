//
//  PlayerView.swift
//  Audiopig
//

import SwiftUI

struct PlayerView: View {
    @Bindable var viewModel: PlayerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            // Drag indicator
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .zIndex(1)

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 32)
                    artworkSection
                    titleSection
                    scrubberSection
                    controlsSection
                    bottomRow
                    Spacer().frame(height: 32)
                }
                .padding(.horizontal, 28)
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $viewModel.isChaptersPresented) {
            ChaptersListView(viewModel: viewModel)
        }
    }

    // MARK: - Artwork

    private var artworkSection: some View {
        Group {
            if let data = viewModel.audiobook?.coverArtwork,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                artworkPlaceholder
            }
        }
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 10)
        .shadow(color: .black.opacity(0.08), radius: 6,  x: 0, y: 2)
        .padding(.top, 8)
        .scaleEffect(viewModel.playbackState == .playing ? 1.0 : 0.94)
        .animation(.spring(response: 0.4, dampingFraction: 0.72), value: viewModel.playbackState == .playing)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemGray4), Color(.systemGray5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .aspectRatio(1, contentMode: .fit)
            Image(systemName: "headphones")
                .font(.system(size: 60))
                .foregroundStyle(Color(.systemGray2))
        }
    }

    // MARK: - Title & Author

    private var titleSection: some View {
        VStack(spacing: 5) {
            Text(viewModel.audiobook?.title ?? "")
                .font(.title2.bold())
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(viewModel.audiobook?.author ?? "")
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.top, 28)
    }

    // MARK: - Scrubber

    private var scrubberSection: some View {
        VStack(spacing: 6) {
            Slider(
                value: $viewModel.scrubPosition,
                in: 0...1,
                onEditingChanged: { editing in
                    if editing {
                        viewModel.beginScrubbing()
                    } else {
                        Task { await viewModel.commitScrub() }
                    }
                }
            )
            .tint(.primary)

            HStack {
                Text(viewModel.scrubDisplayCurrentTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Spacer()

                Text(viewModel.scrubDisplayRemainingTime)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 28)
    }

    // MARK: - Transport Controls

    private var controlsSection: some View {
        HStack(spacing: 0) {
            Spacer()

            // Skip backward
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Spacer()

            // Play / Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.accentColor.opacity(0.38), radius: 14, y: 5)

                    if viewModel.playbackState == .loading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                    } else {
                        Image(systemName: viewModel.playPauseImage)
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            // Skip forward
            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.top, 36)
    }

    // MARK: - Bottom Row (speed + chapters)

    private var bottomRow: some View {
        HStack(spacing: 16) {
            Spacer()
            speedMenu
            chaptersButton
            Spacer()
        }
        .padding(.top, 30)
    }

    private var speedMenu: some View {
        Menu {
            ForEach(PlayerViewModel.availableSpeeds, id: \.self) { speed in
                Button {
                    viewModel.setSpeed(speed)
                } label: {
                    let label = speed.truncatingRemainder(dividingBy: 1) == 0
                        ? "\(Int(speed))×"
                        : String(format: "%.2g×", speed)

                    if speed == viewModel.playbackSpeed {
                        Label(label, systemImage: "checkmark")
                    } else {
                        Text(label)
                    }
                }
            }
        } label: {
            Text(viewModel.speedLabel)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color(.secondarySystemBackground)))
        }
    }

    private var chaptersButton: some View {
        Button {
            viewModel.isChaptersPresented = true
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(.callout, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 18)
                .padding(.vertical, 9)
                .background(Capsule().fill(Color(.secondarySystemBackground)))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.chapters.isEmpty)
    }
}

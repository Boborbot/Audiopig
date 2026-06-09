//
//  MiniPlayerView.swift
//  Audiopig
//
//  A compact persistent playback bar that sits above the tab bar.
//  Tapping the artwork/title area opens the full PlayerView (handled by the caller).
//  The transport buttons are hit-tested independently so taps never bleed through.
//

import SwiftUI

struct MiniPlayerView: View {
    let viewModel: PlayerViewModel
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {

            // Left: art + title — tapping opens the full player
            Button(action: onTap) {
                HStack(spacing: 12) {
                    coverArt
                    titleStack
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Skip backward 15 s
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Play / Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    if viewModel.playbackState == .loading {
                        ProgressView()
                            .tint(.primary)
                    } else {
                        Image(systemName: viewModel.playPauseImage)
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background {
            Rectangle()
                .fill(.thinMaterial)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.5))
                        .frame(height: 0.5)
                }
        }
    }

    // MARK: - Sub-views

    private var coverArt: some View {
        Group {
            if let data = viewModel.audiobook?.coverArtwork,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "headphones")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(.systemGray2))
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.audiobook?.title ?? "")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(viewModel.audiobook?.author ?? "")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

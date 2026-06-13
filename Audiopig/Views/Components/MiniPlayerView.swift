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

    /// Average colour of the current cover art — recomputed only when the image changes.
    private var artworkTint: Color? { viewModel.coverImage?.miniPlayerTint }

    var body: some View {
        HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {

            // Left: art + title — tapping opens the full player
            Button(action: onTap) {
                HStack(spacing: DS.Spacing.sm) {
                    coverArt
                    titleStack
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Skip backward
            Button {
                viewModel.skipBackward()
            } label: {
                Image(systemName: "gobackward.\(viewModel.skipBackwardIntervalSeconds)")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(DS.Color.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(DS.ButtonStyle.transport)

            // Play / Pause
            Button {
                viewModel.togglePlayPause()
            } label: {
                ZStack {
                    if viewModel.playbackState == .loading {
                        ProgressView()
                            .tint(DS.Color.primary)
                    } else {
                        Image(systemName: viewModel.playPauseImage)
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(DS.Color.primary)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(DS.ButtonStyle.transport)

            // Skip forward
            Button {
                viewModel.skipForward()
            } label: {
                Image(systemName: "goforward.\(viewModel.skipForwardIntervalSeconds)")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(DS.Color.primary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(DS.ButtonStyle.transport)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, 11)
        .background {
            MiniPlayerPillBackground(
                progress: viewModel.scrubPosition,
                tintColor: artworkTint
            )
        }
    }

    // MARK: - Sub-views

    private var coverArt: some View {
        Group {
            if let uiImage = viewModel.coverImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    DS.Color.artworkPlaceholder
                    Image(systemName: "headphones")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(UIColor.systemGray2))
                }
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
    }

    private var titleStack: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.playerTitle)
                .font(DS.Typography.listTitle)
                .foregroundStyle(DS.Color.primary)
                .lineLimit(1)

            Text(viewModel.audiobook?.author ?? "")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)
                .lineLimit(1)
        }
    }
}

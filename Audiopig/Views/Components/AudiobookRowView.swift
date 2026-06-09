//
//  AudiobookRowView.swift
//  Audiopig
//

import SwiftUI

struct AudiobookRowView: View {
    let audiobook: Audiobook
    let isSelectionModeActive: Bool
    let isSelected: Bool
    let onTap: () -> Void
    let onToggleSelection: () -> Void

    var body: some View {
        Button {
            if isSelectionModeActive {
                onToggleSelection()
            } else {
                onTap()
            }
        } label: {
            HStack(spacing: 14) {
                selectionIndicator
                coverArtwork
                bookInfo
                Spacer(minLength: 0)
                progressIndicator
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isSelectionModeActive)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelectionModeActive {
            ZStack {
                Circle()
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray3), lineWidth: 1.5)
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 24, height: 24)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .transition(.scale.combined(with: .opacity))
        }
    }

    private var coverArtwork: some View {
        Group {
            if let data = audiobook.coverArtwork,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(.systemGray5)
                    Image(systemName: "headphones")
                        .font(.title3)
                        .foregroundStyle(Color(.systemGray2))
                }
            }
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var bookInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(audiobook.title)
                .font(.system(.callout, design: .default, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(audiobook.author)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(AudiobookProgressFormatter.progressText(
                currentTime: audiobook.currentPlaybackTime,
                duration: audiobook.duration
            ))
            .font(.caption)
            .foregroundStyle(Color(.tertiaryLabel))
            .lineLimit(1)
            .padding(.top, 2)
        }
    }

    private var progressIndicator: some View {
        CircularProgressView(
            progress: AudiobookProgressFormatter.progress(
                currentTime: audiobook.currentPlaybackTime,
                duration: audiobook.duration
            )
        )
        .frame(width: 36, height: 36)
    }
}

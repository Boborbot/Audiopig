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
            HStack(spacing: DS.Spacing.sm + DS.Spacing.xs) {
                selectionIndicator
                coverArtwork
                bookInfo
                Spacer(minLength: 0)
                progressIndicator
            }
            .contentShape(Rectangle())
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + DS.Spacing.xs)
        }
        .buttonStyle(.plain)
        .animation(DS.Animation.standard, value: isSelectionModeActive)
        .animation(DS.Animation.snappy, value: isSelected)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelectionModeActive {
            ZStack {
                Circle()
                    .stroke(
                        isSelected ? DS.Color.coral : Color(UIColor.systemGray3),
                        lineWidth: 1.5
                    )
                    .frame(width: 24, height: 24)

                if isSelected {
                    Circle()
                        .fill(DS.Color.coral)
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
        ZStack(alignment: .topTrailing) {
            Group {
                if let uiImage = CoverArtCache.shared.image(for: audiobook) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        audiobook.placeholderColor.opacity(0.75)
                        Image(systemName: "headphones")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .frame(width: 60, height: 60)
            .listCoverArtClip()

            if audiobook.isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DS.Color.coral)
                    .background(
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .padding(-2)
                    )
                    .offset(x: 4, y: -4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(DS.Animation.snappy, value: audiobook.isFinished)
    }

    private var bookInfo: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(audiobook.title)
                .font(DS.Typography.listTitle)
                .foregroundStyle(DS.Color.primary)
                .lineLimit(1)

            Text(audiobook.author)
                .font(.subheadline)
                .foregroundStyle(DS.Color.secondary)
                .lineLimit(1)

            Text(AudiobookProgressFormatter.progressText(
                currentTime: audiobook.currentPlaybackTime,
                duration: audiobook.duration,
                isManuallyFinished: audiobook.isManuallyFinished
            ))
            .font(DS.Typography.caption)
            .foregroundStyle(DS.Color.tertiary)
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

//
//  MissingCoverHintBanner.swift
//  Audiopig
//
//  Subtle post-import hint when a single book has no embedded cover art.
//

import SwiftUI

struct MissingCoverHintBanner: View {

    let title: String
    let onAddArtwork: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onAddArtwork) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DS.Color.coral)

                    Text("No cover for \(title)")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.primary)
                        .lineLimit(1)

                    Text("Add")
                        .font(DS.Typography.caption.weight(.semibold))
                        .foregroundStyle(DS.Color.coral)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(DS.Color.tertiary)
                    .padding(DS.Spacing.xs)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .fill(DS.Color.secondarySurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous)
                .strokeBorder(DS.Color.separator.opacity(0.6), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No cover for \(title). Add artwork.")
        .accessibilityHint("Opens edit details to add cover art.")
    }
}

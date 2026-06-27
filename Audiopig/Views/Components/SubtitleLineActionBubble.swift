//
//  SubtitleLineActionBubble.swift
//  Audiopig
//

import SwiftUI

struct SubtitleLineActionBubble: View {
    let onCopy: () -> Void
    let onBookmark: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            Button(action: onCopy) {
                Image(systemName: "square.on.square")
                    .font(.system(size: 17, weight: .medium))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(Color.white)
                    .frame(width: 40, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Copy")

            Button(action: onBookmark) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 18, weight: .medium))
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(Color.white)
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.55))
                        .offset(x: 6, y: 4)
                }
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add bookmark")
        }
        .padding(.horizontal, DS.Spacing.xs)
        .padding(.vertical, DS.Spacing.xs)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(Color.white.opacity(0.14))
                }
        }
        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
    }
}

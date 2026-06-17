//
//  PlaybackSourcePickerView.swift
//  AudiopigWatch
//

import SwiftUI

struct PlaybackSourcePickerView: View {
    var onSelectPhone: () -> Void
    var onSelectWatch: () -> Void

    var body: some View {
        VStack(spacing: WDS.Spacing.md) {
            HStack(spacing: WDS.Spacing.md) {
                sourceButton(
                    systemImage: "iphone",
                    title: "iPhone playback",
                    isEnabled: true,
                    showsUnderConstruction: false,
                    action: onSelectPhone
                )
                sourceButton(
                    systemImage: "applewatch",
                    title: "Watch playback",
                    isEnabled: WatchFeatures.localPlaybackEnabled,
                    showsUnderConstruction: !WatchFeatures.localPlaybackEnabled,
                    action: onSelectWatch
                )
            }
        }
        .padding()
    }

    private func sourceButton(
        systemImage: String,
        title: String,
        isEnabled: Bool,
        showsUnderConstruction: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: WDS.Spacing.sm) {
                    Image(systemName: systemImage)
                        .font(.title2)
                        .foregroundStyle(isEnabled ? WDS.Color.coral : .secondary)
                    Text(title)
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(isEnabled ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, WDS.Spacing.md)
                .background(WDS.Color.placeholder.opacity(isEnabled ? 0.5 : 0.35))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if showsUnderConstruction {
                    Image(systemName: "hammer.circle.fill")
                        .font(.caption)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(WDS.Color.coral, .secondary.opacity(0.25))
                        .padding(6)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

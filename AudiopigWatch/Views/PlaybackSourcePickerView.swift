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
                    title: "iPhone",
                    action: onSelectPhone
                )
                sourceButton(
                    systemImage: "applewatch",
                    title: "Watch",
                    action: onSelectWatch
                )
            }
        }
        .padding()
    }

    private func sourceButton(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: WDS.Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(WDS.Color.coral)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WDS.Spacing.md)
            .background(WDS.Color.placeholder.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

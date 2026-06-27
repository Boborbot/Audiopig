//
//  VoiceBoostLevelPicker.swift
//  Audiopig
//

import SwiftUI

struct VoiceBoostLevelPicker: View {
    let activeLevel: VoiceBoostLevel
    var isDisabled: Bool = false
    let onSelect: (VoiceBoostLevel) -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.xs) {
            ForEach(VoiceBoostLevel.allCases) { level in
                Button {
                    onSelect(level)
                } label: {
                    Text(level.label)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(VoiceBoostPillButtonStyle(isActive: level == activeLevel))
                .disabled(isDisabled)
                .accessibilityAddTraits(level == activeLevel ? .isSelected : [])
            }
        }
    }
}

// MARK: - Pill Style

private struct VoiceBoostPillButtonStyle: ButtonStyle {
    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.controlLabel)
            .foregroundStyle(isActive ? DS.Color.coral : DS.Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color(UIColor.secondarySystemBackground)))
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .animation(DS.Animation.snappy, value: configuration.isPressed)
    }
}

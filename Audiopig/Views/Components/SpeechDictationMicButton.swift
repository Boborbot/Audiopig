//
//  SpeechDictationMicButton.swift
//  Audiopig
//

import SwiftUI

struct SpeechDictationMicButton: View {
    let isRecording: Bool
    let accessibilityLabel: String
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            Image(systemName: isRecording ? "mic.fill" : "mic")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isRecording ? DS.Color.coral : DS.Color.secondary)
                .symbolEffect(
                    .variableColor.iterative.dimInactiveLayers,
                    options: .repeating.speed(0.45),
                    isActive: isRecording && !reduceMotion
                )
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isRecording ? "Stop dictation" : accessibilityLabel)
        .accessibilityAddTraits(isRecording ? [.isSelected] : [])
    }
}

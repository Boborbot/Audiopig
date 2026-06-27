//
//  AudioEnhancementControls.swift
//  Audiopig
//
//  Shared Voice Boost + EQ controls used in the player sheet and playback settings.
//

import SwiftUI

struct AudioEnhancementControls: View {
    @Binding var eqPresetID: String
    @Binding var rememberedEQPresetID: String
    @Binding var voiceBoostLevel: VoiceBoostLevel
    var scopeLabel: String?
    var isDisabled: Bool = false
    var hasEQAccess: Bool = true
    var onSettingsChanged: (() -> Void)?

    private var activePreset: SpeechEQPreset {
        SpeechEQPreset.validated(eqPresetID)
    }

    private var isEQEnabled: Bool {
        eqPresetID != SpeechEQPreset.off.id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            if let scopeLabel {
                Text(scopeLabel)
                    .font(DS.Typography.sectionHeader)
                    .foregroundStyle(DS.Color.primary)
                    .accessibilityAddTraits(.isHeader)
            }

            sectionHeader(title: "Voice Boost", value: voiceBoostLevel.label)

            VoiceBoostLevelPicker(
                activeLevel: voiceBoostLevel,
                isDisabled: isDisabled,
                onSelect: { voiceBoostLevel = $0 }
            )

            sectionHeader(
                title: "Equalizer",
                value: isEQEnabled ? activePreset.label : "Off"
            )

            Toggle(isOn: eqEnabledBinding) {
                Label("EQ", systemImage: "slider.vertical.3")
                    .font(DS.Typography.listBody)
                    .foregroundStyle(DS.Color.primary)
            }
            .tint(DS.Color.coral)
            .disabled(isDisabled || !hasEQAccess)
            .opacity(hasEQAccess ? 1 : 0.45)

            EQPresetPicker(
                presets: SpeechEQPreset.all,
                activePresetID: eqPresetID,
                isEQEnabled: isEQEnabled,
                isDisabled: isDisabled || !hasEQAccess,
                onSelect: { eqPresetID = $0 }
            )
            .opacity(hasEQAccess ? 1 : 0.45)
        }
        .onChange(of: eqPresetID) { _, newValue in
            if newValue != SpeechEQPreset.off.id {
                rememberedEQPresetID = newValue
            }
            onSettingsChanged?()
        }
        .onChange(of: voiceBoostLevel) { _, _ in onSettingsChanged?() }
    }

    private func sectionHeader(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.primary)

            Spacer()

            Text(value)
                .font(DS.Typography.controlLabel)
                .foregroundStyle(DS.Color.coral)
        }
    }

    private var eqEnabledBinding: Binding<Bool> {
        Binding(
            get: { isEQEnabled },
            set: { enabled in
                if enabled {
                    eqPresetID = SpeechEQPreset.restoredEnabledID(remembered: rememberedEQPresetID)
                } else {
                    if eqPresetID != SpeechEQPreset.off.id {
                        rememberedEQPresetID = eqPresetID
                    }
                    eqPresetID = SpeechEQPreset.off.id
                }
            }
        )
    }
}

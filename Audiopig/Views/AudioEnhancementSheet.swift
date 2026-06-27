//
//  AudioEnhancementSheet.swift
//  Audiopig
//

import SwiftUI

struct AudioEnhancementSheet: View {
    let viewModel: PlayerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                AudioEnhancementControls(
                    eqPresetID: eqPresetBinding,
                    rememberedEQPresetID: rememberedEQPresetBinding,
                    voiceBoostLevel: voiceBoostBinding,
                    hasEQAccess: viewModel.hasEQAccess
                )
                .padding(.horizontal, DS.Spacing.md)

                if !viewModel.hasEQAccess {
                    Text("EQ presets are included with AudioPig Plus. Voice Boost is free.")
                        .font(DS.Typography.caption)
                        .foregroundStyle(DS.Color.tertiary)
                        .padding(.horizontal, DS.Spacing.lg)
                }
            }
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass()
        .presentationDetents([.fraction(0.62)])
        .presentationDragIndicator(.visible)
    }

    private var eqPresetBinding: Binding<String> {
        Binding(
            get: { viewModel.activeEQPresetID },
            set: { viewModel.setEQPreset($0) }
        )
    }

    private var rememberedEQPresetBinding: Binding<String> {
        Binding(
            get: { viewModel.rememberedEQPresetID },
            set: { viewModel.setRememberedEQPresetID($0) }
        )
    }

    private var voiceBoostBinding: Binding<VoiceBoostLevel> {
        Binding(
            get: { viewModel.voiceBoostLevel },
            set: { viewModel.setVoiceBoostLevel($0) }
        )
    }
}

//
//  AudioEnhancementResolver.swift
//  AudiopigShared
//

import Foundation

public struct AudioEnhancementSettings: Sendable, Equatable {
    public let eqPresetID: String
    public let voiceBoostLevel: VoiceBoostLevel

    public init(eqPresetID: String, voiceBoostLevel: VoiceBoostLevel) {
        self.eqPresetID = eqPresetID
        self.voiceBoostLevel = voiceBoostLevel
    }
}

public enum AudioEnhancementResolver {
    public static func resolve(
        universalEnabled: Bool,
        universalEQPresetID: String,
        universalVoiceBoostLevel: VoiceBoostLevel,
        perBookEQPresetID: String?,
        perBookVoiceBoostLevel: VoiceBoostLevel?,
        defaultEQPresetID: String,
        defaultVoiceBoostLevel: VoiceBoostLevel
    ) -> AudioEnhancementSettings {
        if universalEnabled {
            return AudioEnhancementSettings(
                eqPresetID: SpeechEQPreset.validated(universalEQPresetID).id,
                voiceBoostLevel: universalVoiceBoostLevel
            )
        }
        let eqID = perBookEQPresetID.map { SpeechEQPreset.validated($0).id }
            ?? SpeechEQPreset.validated(defaultEQPresetID).id
        let boost = perBookVoiceBoostLevel ?? defaultVoiceBoostLevel
        return AudioEnhancementSettings(eqPresetID: eqID, voiceBoostLevel: boost)
    }
}

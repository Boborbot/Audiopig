//
//  SpeechEQPresetTests.swift
//  AudiopigTests
//

import XCTest
@testable import Audiopig

final class SpeechEQPresetTests: XCTestCase {

    func testAllPresetIDsAreUnique() {
        let ids = SpeechEQPreset.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testValidatedReturnsKnownPreset() {
        XCTAssertEqual(SpeechEQPreset.validated("clearNarration").id, "clearNarration")
    }

    func testValidatedMigratesLegacyVoiceForwardID() {
        XCTAssertEqual(SpeechEQPreset.validated("voiceForward").id, "clearNarration")
    }

    func testValidatedFallsBackToOffForUnknownID() {
        XCTAssertEqual(SpeechEQPreset.validated("not-a-preset").id, "off")
    }

    func testRestoredEnabledIDReturnsRememberedPreset() {
        XCTAssertEqual(
            SpeechEQPreset.restoredEnabledID(remembered: "warmVoice"),
            "warmVoice"
        )
    }

    func testRestoredEnabledIDFallsBackWhenRememberedIsOff() {
        XCTAssertEqual(
            SpeechEQPreset.restoredEnabledID(remembered: SpeechEQPreset.off.id),
            SpeechEQPreset.clearSpeech.id
        )
    }

    func testRestoredEnabledIDUsesCustomFallback() {
        XCTAssertEqual(
            SpeechEQPreset.restoredEnabledID(
                remembered: SpeechEQPreset.off.id,
                fallback: SpeechEQPreset.podcast.id
            ),
            SpeechEQPreset.podcast.id
        )
    }

    func testMusicalScorePresetsAreGroupedTogether() {
        let scoreIDs = Set(SpeechEQPreset.presets(in: .musicalScores).map(\.id))
        XCTAssertEqual(scoreIDs, ["clearNarration", "cinematicMode", "bassBoost"])
    }

    func testAllPresetsMapToExactlyOneCategory() {
        XCTAssertEqual(SpeechEQPreset.all.count, 10)

        for category in SpeechEQCategory.allCases {
            let grouped = SpeechEQPreset.presets(in: category)
            XCTAssertFalse(grouped.isEmpty, "Expected presets in \(category)")
            for preset in grouped {
                XCTAssertEqual(preset.category, category)
            }
        }

        let categoryCounts = SpeechEQCategory.allCases.map {
            SpeechEQPreset.presets(in: $0).count
        }
        XCTAssertEqual(categoryCounts.reduce(0, +), SpeechEQPreset.all.count)
    }

    func testCategoryGroupingMatchesPlan() {
        XCTAssertEqual(SpeechEQPreset.presets(in: .neutral).map(\.id), ["off"])
        XCTAssertEqual(
            Set(SpeechEQPreset.presets(in: .clarity).map(\.id)),
            ["clearSpeech", "brightCrisp", "podcast"]
        )
        XCTAssertEqual(
            Set(SpeechEQPreset.presets(in: .toneAndCut).map(\.id)),
            ["warmVoice", "reduceHarshness", "lowRumbleCut"]
        )
        XCTAssertEqual(
            Set(SpeechEQPreset.presets(in: .musicalScores).map(\.id)),
            ["clearNarration", "cinematicMode", "bassBoost"]
        )
    }

    func testSelectablePresetsHaveTwoLineTileTitles() {
        let selectable = SpeechEQPreset.all.filter { $0.id != SpeechEQPreset.off.id }
        for preset in selectable {
            let lines = preset.tileTitleLines
            XCTAssertFalse(lines.first.isEmpty, preset.id)
            XCTAssertFalse(lines.first.trimmingCharacters(in: .whitespaces).isEmpty, preset.id)
        }
    }
}

final class AudioEnhancementResolverTests: XCTestCase {

    func testUniversalModeUsesUniversalValues() {
        let resolved = AudioEnhancementResolver.resolve(
            universalEnabled: true,
            universalEQPresetID: "podcast",
            universalVoiceBoostLevel: .strong,
            perBookEQPresetID: "warmVoice",
            perBookVoiceBoostLevel: .off,
            defaultEQPresetID: "off",
            defaultVoiceBoostLevel: .off
        )
        XCTAssertEqual(resolved.eqPresetID, "podcast")
        XCTAssertEqual(resolved.voiceBoostLevel, .strong)
    }

    func testPerBookModeUsesStoredBookValues() {
        let resolved = AudioEnhancementResolver.resolve(
            universalEnabled: false,
            universalEQPresetID: "podcast",
            universalVoiceBoostLevel: .strong,
            perBookEQPresetID: "clearSpeech",
            perBookVoiceBoostLevel: .balanced,
            defaultEQPresetID: "off",
            defaultVoiceBoostLevel: .off
        )
        XCTAssertEqual(resolved.eqPresetID, "clearSpeech")
        XCTAssertEqual(resolved.voiceBoostLevel, .balanced)
    }

    func testPerBookModeFallsBackToDefaults() {
        let resolved = AudioEnhancementResolver.resolve(
            universalEnabled: false,
            universalEQPresetID: "podcast",
            universalVoiceBoostLevel: .strong,
            perBookEQPresetID: nil,
            perBookVoiceBoostLevel: nil,
            defaultEQPresetID: "warmVoice",
            defaultVoiceBoostLevel: .light
        )
        XCTAssertEqual(resolved.eqPresetID, "warmVoice")
        XCTAssertEqual(resolved.voiceBoostLevel, .light)
    }

    func testLegacyVoiceForwardResolvesToClearNarration() {
        let resolved = AudioEnhancementResolver.resolve(
            universalEnabled: false,
            universalEQPresetID: "off",
            universalVoiceBoostLevel: .off,
            perBookEQPresetID: "voiceForward",
            perBookVoiceBoostLevel: nil,
            defaultEQPresetID: "off",
            defaultVoiceBoostLevel: .off
        )
        XCTAssertEqual(resolved.eqPresetID, "clearNarration")
    }
}

final class BiquadFilterTests: XCTestCase {

    func testHighPassAttenuatesVeryLowFrequency() {
        var filter = BiquadFilter()
        filter.configure(kind: .highPass, sampleRate: 44_100, frequency: 200, q: 0.707, gainDB: 0)

        var lowOutput: Float = 0
        for _ in 0..<512 {
            lowOutput = filter.process(1)
        }
        XCTAssertLessThan(abs(lowOutput), 0.2)
    }

    func testVoiceBoostStrongIsBoldOnQuietPassage() {
        var boost = VoiceBoostProcessor()
        boost.setSampleRate(44_100)

        var output: Float = 0
        for _ in 0..<512 {
            output = boost.process(0.08, maxBoost: VoiceBoostLevel.strong.maxBoost)
        }
        XCTAssertGreaterThan(abs(output), 0.12)
        XCTAssertLessThan(abs(output), 0.25)
    }

    func testVoiceBoostLevelsIncreaseMonotonically() {
        let quietInput: Float = 0.08
        let settleFrames = 512

        func settledOutput(for level: VoiceBoostLevel) -> Float {
            var boost = VoiceBoostProcessor()
            boost.setSampleRate(44_100)
            var output: Float = 0
            for _ in 0..<settleFrames {
                output = boost.process(quietInput, maxBoost: level.maxBoost)
            }
            return abs(output)
        }

        let light = settledOutput(for: .light)
        let balanced = settledOutput(for: .balanced)
        let strong = settledOutput(for: .strong)

        XCTAssertGreaterThan(light, quietInput)
        XCTAssertGreaterThan(balanced, light)
        XCTAssertGreaterThan(strong, balanced)
    }

    func testVoiceBoostOffPassesThrough() {
        var boost = VoiceBoostProcessor()
        boost.setSampleRate(44_100)

        let output = boost.process(0.05, maxBoost: VoiceBoostLevel.off.maxBoost)
        XCTAssertEqual(output, 0.05)
    }
}

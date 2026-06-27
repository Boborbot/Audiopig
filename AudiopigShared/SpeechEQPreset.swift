//
//  SpeechEQPreset dynamic.swift
//  AudiopigShared
//

import Foundation

public enum SpeechEQCategory: String, CaseIterable, Sendable {
    case neutral
    case clarity
    case toneAndCut
    case musicalScores

    public var title: String {
        switch self {
        case .neutral:
            return "Neutral"
        case .clarity:
            return "Clarity"
        case .toneAndCut:
            return "Tone & Cut"
        case .musicalScores:
            return "For Books With Musical Scores"
        }
    }

    public var showsMusicNote: Bool {
        self == .musicalScores
    }
}

public struct EQBandDefinition: Sendable, Equatable {
    public let kind: BiquadFilterKind
    public let frequency: Float
    public let q: Float
    public let gainDB: Float

    public init(kind: BiquadFilterKind, frequency: Float, q: Float, gainDB: Float) {
        self.kind = kind
        self.frequency = frequency
        self.q = q
        self.gainDB = gainDB
    }
}

/// Fixed speech-focused EQ preset for audiobook playback.
public struct SpeechEQPreset: Sendable, Identifiable, Equatable {
    public let id: String
    public let label: String
    public let category: SpeechEQCategory
    public let isRecommendedForSpeechWithMusic: Bool
    public let bands: [EQBandDefinition]

    public init(
        id: String,
        label: String,
        category: SpeechEQCategory,
        isRecommendedForSpeechWithMusic: Bool = false,
        bands: [EQBandDefinition]
    ) {
        self.id = id
        self.label = label
        self.category = category
        self.isRecommendedForSpeechWithMusic = isRecommendedForSpeechWithMusic
        self.bands = bands
    }

    public var isBypass: Bool { bands.isEmpty }

    /// Two-line title for the EQ carousel. Second line is empty when the label fits on one row.
    public var tileTitleLines: (first: String, second: String) {
        switch id {
        case Self.clearSpeech.id:
            return ("Clear", "Speech")
        case Self.warmVoice.id:
            return ("Warm", "Voice")
        case Self.brightCrisp.id:
            return ("Bright &", "Crisp")
        case Self.reduceHarshness.id:
            return ("Reduce", "Harshness")
        case Self.lowRumbleCut.id:
            return ("Low Rumble", "Cut")
        case Self.clearNarration.id:
            return ("Clear", "Narration")
        case Self.cinematicMode.id:
            return ("Cinematic", "Mode")
        case Self.bassBoost.id:
            return ("Bass", "Boost")
        case Self.podcast.id:
            return ("Podcast", "")
        case "voiceForward":
            return ("Clear", "Narration")
        default:
            return (label, "")
        }
    }

    public static let off = SpeechEQPreset(
        id: "off",
        label: "Off",
        category: .neutral,
        bands: []
    )

    public static let clearSpeech = SpeechEQPreset(
        id: "clearSpeech",
        label: "Clear Speech",
        category: .clarity,
        bands: [
            EQBandDefinition(kind: .highPass, frequency: 100, q: 0.707, gainDB: 0),
            EQBandDefinition(kind: .peaking, frequency: 250, q: 1.0, gainDB: -2),
            EQBandDefinition(kind: .peaking, frequency: 3_000, q: 1.0, gainDB: 3),
        ]
    )

    public static let warmVoice = SpeechEQPreset(
        id: "warmVoice",
        label: "Warm Voice",
        category: .toneAndCut,
        bands: [
            EQBandDefinition(kind: .highPass, frequency: 80, q: 0.707, gainDB: 0),
            EQBandDefinition(kind: .peaking, frequency: 300, q: 0.8, gainDB: 2),
            EQBandDefinition(kind: .highShelf, frequency: 8_000, q: 0.707, gainDB: -2),
        ]
    )

    public static let brightCrisp = SpeechEQPreset(
        id: "brightCrisp",
        label: "Bright & Crisp",
        category: .clarity,
        bands: [
            EQBandDefinition(kind: .highPass, frequency: 120, q: 0.707, gainDB: 0),
            EQBandDefinition(kind: .peaking, frequency: 2_500, q: 1.0, gainDB: 3),
            EQBandDefinition(kind: .peaking, frequency: 6_000, q: 0.8, gainDB: 2),
        ]
    )

    public static let reduceHarshness = SpeechEQPreset(
        id: "reduceHarshness",
        label: "Reduce Harshness",
        category: .toneAndCut,
        bands: [
            EQBandDefinition(kind: .peaking, frequency: 4_000, q: 1.5, gainDB: -4),
            EQBandDefinition(kind: .peaking, frequency: 5_500, q: 1.0, gainDB: -3),
        ]
    )

    public static let lowRumbleCut = SpeechEQPreset(
        id: "lowRumbleCut",
        label: "Low Rumble Cut",
        category: .toneAndCut,
        bands: [
            EQBandDefinition(kind: .highPass, frequency: 200, q: 1.0, gainDB: 0),
            EQBandDefinition(kind: .highPass, frequency: 120, q: 0.707, gainDB: 0),
        ]
    )

    public static let clearNarration = SpeechEQPreset(
        id: "clearNarration",
        label: "Clear Narration",
        category: .musicalScores,
        isRecommendedForSpeechWithMusic: true,
        bands: [
            EQBandDefinition(kind: .highPass, frequency: 150, q: 0.707, gainDB: 0),
            EQBandDefinition(kind: .lowShelf, frequency: 200, q: 0.707, gainDB: -2),
            EQBandDefinition(kind: .peaking, frequency: 2_000, q: 0.9, gainDB: 2.5),
            EQBandDefinition(kind: .peaking, frequency: 3_500, q: 1.0, gainDB: 2),
        ]
    )

    public static let cinematicMode = SpeechEQPreset(
        id: "cinematicMode",
        label: "Cinematic Mode",
        category: .musicalScores,
        isRecommendedForSpeechWithMusic: true,
        bands: [
            EQBandDefinition(kind: .highPass, frequency: 80, q: 0.707, gainDB: 0),
            EQBandDefinition(kind: .lowShelf, frequency: 150, q: 0.707, gainDB: 1.5),
            EQBandDefinition(kind: .peaking, frequency: 3_000, q: 0.8, gainDB: -1.5),
            EQBandDefinition(kind: .highShelf, frequency: 10_000, q: 0.707, gainDB: 1),
        ]
    )

    public static let bassBoost = SpeechEQPreset(
        id: "bassBoost",
        label: "Bass Boost",
        category: .musicalScores,
        isRecommendedForSpeechWithMusic: true,
        bands: [
            EQBandDefinition(kind: .highPass, frequency: 70, q: 0.707, gainDB: 0),
            EQBandDefinition(kind: .lowShelf, frequency: 120, q: 0.707, gainDB: 2),
            EQBandDefinition(kind: .lowShelf, frequency: 220, q: 0.8, gainDB: 1.5),
        ]
    )

    public static let podcast = SpeechEQPreset(
        id: "podcast",
        label: "Podcast",
        category: .clarity,
        bands: [
            EQBandDefinition(kind: .highPass, frequency: 100, q: 0.707, gainDB: 0),
            EQBandDefinition(kind: .peaking, frequency: 2_800, q: 1.2, gainDB: 2),
        ]
    )

    public static let all: [SpeechEQPreset] = [
        .off,
        .clearSpeech,
        .warmVoice,
        .brightCrisp,
        .reduceHarshness,
        .lowRumbleCut,
        .podcast,
        .clearNarration,
        .cinematicMode,
        .bassBoost,
    ]

    public static func preset(for id: String) -> SpeechEQPreset? {
        if id == "voiceForward" {
            return clearNarration
        }
        return all.first { $0.id == id }
    }

    public static func presets(in category: SpeechEQCategory) -> [SpeechEQPreset] {
        all.filter { $0.category == category }
    }

    public static func validated(_ id: String) -> SpeechEQPreset {
        preset(for: id) ?? .off
    }
}

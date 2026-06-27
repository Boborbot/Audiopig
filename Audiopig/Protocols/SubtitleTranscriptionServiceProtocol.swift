//
//  SubtitleTranscriptionServiceProtocol.swift
//  Audiopig
//

import Foundation

enum SubtitleTranscriptionError: LocalizedError, Equatable {
    case unsupportedOS
    case speechPermissionDenied
    case localeNotInstalled
    case localeDownloadFailed
    case audioExtractionFailed
    case transcriptionFailed
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "Subtitles require iOS 26 or later."
        case .speechPermissionDenied:
            return "Speech recognition permission is required for subtitles. Enable it in Settings → Audiopig → Speech Recognition."
        case .localeNotInstalled:
            return "Speech recognition for this language is not available on this device."
        case .localeDownloadFailed:
            return "Could not download the speech recognition language pack. Connect to Wi‑Fi and try again."
        case .audioExtractionFailed:
            return "Could not prepare audio for transcription."
        case .transcriptionFailed:
            return "Transcription failed. Try again with playback paused."
        case .cancelled:
            return "Transcription was cancelled."
        }
    }
}

struct SubtitleLocaleDownloadProgress: Sendable {
    let fractionCompleted: Double
}

protocol SubtitleTranscriptionServiceProtocol: Sendable {
    var isSupported: Bool { get }

    func ensureLocaleReady(
        localeIdentifier: String,
        progress: (@Sendable (SubtitleLocaleDownloadProgress) -> Void)?
    ) async throws

    func transcribeWindow(
        fileURL: URL,
        fileLocalStart: TimeInterval,
        fileLocalEnd: TimeInterval,
        globalOffset: TimeInterval,
        localeIdentifier: String
    ) async throws -> [SubtitleCueTiming]
}

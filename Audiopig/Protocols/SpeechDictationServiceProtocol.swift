//
//  SpeechDictationServiceProtocol.swift
//  Audiopig
//

import Foundation

enum SpeechDictationError: LocalizedError, Equatable {
    case speechPermissionDenied
    case microphonePermissionDenied
    case recognizerUnavailable
    case audioSessionFailed
    case audioEngineFailed

    var errorDescription: String? {
        switch self {
        case .speechPermissionDenied:
            return "Speech recognition permission is required. Enable it in Settings → Audiopig → Speech Recognition."
        case .microphonePermissionDenied:
            return "Microphone access is required to dictate bookmark text. Enable it in Settings → Audiopig → Microphone."
        case .recognizerUnavailable:
            return "Speech recognition is not available for this language on this device."
        case .audioSessionFailed:
            return "Could not configure audio for dictation."
        case .audioEngineFailed:
            return "Could not start the microphone."
        }
    }
}

@MainActor
protocol SpeechDictationServiceProtocol: AnyObject {
    var isRecording: Bool { get }

    func start(onUpdate: @escaping @MainActor (String) -> Void) async throws
    func stop()
}

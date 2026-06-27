//
//  SubtitleTranscriptionService.swift
//  Audiopig
//

import Foundation

/// Facade that routes to the iOS 26 SpeechAnalyzer implementation when available.
struct SubtitleTranscriptionService: SubtitleTranscriptionServiceProtocol {

    var isSupported: Bool {
        if #available(iOS 26, *) {
            return true
        }
        return false
    }

    func ensureLocaleReady(
        localeIdentifier: String,
        progress: (@Sendable (SubtitleLocaleDownloadProgress) -> Void)?
    ) async throws {
        if #available(iOS 26, *) {
            try await SubtitleTranscriptionServiceIOS26.shared.ensureLocaleReady(
                localeIdentifier: localeIdentifier,
                progress: progress
            )
        } else {
            throw SubtitleTranscriptionError.unsupportedOS
        }
    }

    func transcribeWindow(
        fileURL: URL,
        fileLocalStart: TimeInterval,
        fileLocalEnd: TimeInterval,
        globalOffset: TimeInterval,
        localeIdentifier: String
    ) async throws -> [SubtitleCueTiming] {
        if #available(iOS 26, *) {
            return try await SubtitleTranscriptionServiceIOS26.shared.transcribeWindow(
                fileURL: fileURL,
                fileLocalStart: fileLocalStart,
                fileLocalEnd: fileLocalEnd,
                globalOffset: globalOffset,
                localeIdentifier: localeIdentifier
            )
        }
        throw SubtitleTranscriptionError.unsupportedOS
    }
}

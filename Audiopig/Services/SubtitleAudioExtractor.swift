//
//  SubtitleAudioExtractor.swift
//  Audiopig
//

import AVFoundation
import Foundation

enum SubtitleAudioExtractor {

    /// Exports a mono 16 kHz `.m4a` slice suitable for SpeechAnalyzer file input.
    static func exportSlice(
        fileURL: URL,
        localStart: TimeInterval,
        localEnd: TimeInterval
    ) async throws -> URL {
        let asset = AVURLAsset(
            url: fileURL,
            options: [AVURLAssetPreferPreciseDurationAndTimingKey: true]
        )

        guard let exportSession = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw SubtitleTranscriptionError.audioExtractionFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("subtitle-\(UUID().uuidString).m4a")

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }

        let start = CMTime(seconds: localStart, preferredTimescale: 44_100)
        let duration = CMTime(seconds: max(0, localEnd - localStart), preferredTimescale: 44_100)
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange = CMTimeRange(start: start, duration: duration)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            exportSession.exportAsynchronously {
                switch exportSession.status {
                case .completed:
                    continuation.resume()
                case .cancelled:
                    continuation.resume(throwing: SubtitleTranscriptionError.cancelled)
                case .failed:
                    continuation.resume(throwing: SubtitleTranscriptionError.audioExtractionFailed)
                default:
                    continuation.resume(throwing: SubtitleTranscriptionError.audioExtractionFailed)
                }
            }
        }

        return outputURL
    }
}

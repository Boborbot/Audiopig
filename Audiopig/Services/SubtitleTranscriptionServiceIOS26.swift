//
//  SubtitleTranscriptionServiceIOS26.swift
//  Audiopig
//

import AVFoundation
import Foundation

#if canImport(Speech)
import Speech
#endif

@available(iOS 26, *)
actor SubtitleTranscriptionServiceIOS26 {

    static let shared = SubtitleTranscriptionServiceIOS26()

    func ensureLocaleReady(
        localeIdentifier: String,
        progress: (@Sendable (SubtitleLocaleDownloadProgress) -> Void)?
    ) async throws {
        #if canImport(Speech)
        try await ensureSpeechPermission()

        let locale = try await resolveLocale(identifier: localeIdentifier)
        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .timeIndexedTranscriptionWithAlternatives
        )

        _ = try await AssetInventory.reserve(locale: locale)

        let installed = await SpeechTranscriber.installedLocales
        if installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            progress?(SubtitleLocaleDownloadProgress(fractionCompleted: 1))
            return
        }

        let status = await AssetInventory.status(forModules: [transcriber])
        switch status {
        case .installed:
            progress?(SubtitleLocaleDownloadProgress(fractionCompleted: 1))
        case .supported, .downloading:
            guard let request = try await AssetInventory.assetInstallationRequest(
                supporting: [transcriber]
            ) else {
                throw SubtitleTranscriptionError.localeNotInstalled
            }
            progress?(SubtitleLocaleDownloadProgress(fractionCompleted: request.progress.fractionCompleted))
            try await request.downloadAndInstall()
            progress?(SubtitleLocaleDownloadProgress(fractionCompleted: 1))
        case .unsupported:
            throw SubtitleTranscriptionError.localeNotInstalled
        }
        #else
        throw SubtitleTranscriptionError.unsupportedOS
        #endif
    }

    func transcribeWindow(
        fileURL: URL,
        fileLocalStart: TimeInterval,
        fileLocalEnd: TimeInterval,
        globalOffset: TimeInterval,
        localeIdentifier: String
    ) async throws -> [SubtitleCueTiming] {
        #if canImport(Speech)
        let sliceURL = try await SubtitleAudioExtractor.exportSlice(
            fileURL: fileURL,
            localStart: fileLocalStart,
            localEnd: fileLocalEnd
        )
        defer { try? FileManager.default.removeItem(at: sliceURL) }

        let locale = try await resolveLocale(identifier: localeIdentifier)
        let transcriber = SpeechTranscriber(
            locale: locale,
            preset: .timeIndexedTranscriptionWithAlternatives
        )
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let timelineOffset = globalOffset + fileLocalStart

        let audioFile = try AVAudioFile(forReading: sliceURL)
        try await analyzer.prepareToAnalyze(in: audioFile.processingFormat)

        let collectTask = Task { () throws -> [TimedTextRun] in
            var runs: [TimedTextRun] = []
            for try await result in transcriber.results {
                runs.append(
                    contentsOf: Self.extractRuns(
                        from: result,
                        globalOffset: timelineOffset
                    )
                )
            }
            return runs
        }

        do {
            if let endTime = try await analyzer.analyzeSequence(from: audioFile) {
                try await analyzer.finalizeAndFinish(through: endTime)
            } else {
                try await analyzer.finalizeAndFinishThroughEndOfInput()
            }
        } catch {
            collectTask.cancel()
            throw error
        }

        let runs = try await collectTask.value
        return SubtitleLineGrouper.groupIntoLines(runs)
        #else
        throw SubtitleTranscriptionError.unsupportedOS
        #endif
    }

    #if canImport(Speech)
    private func ensureSpeechPermission() async throws {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard status == .authorized else {
            throw SubtitleTranscriptionError.speechPermissionDenied
        }
    }

    private func resolveLocale(identifier: String) async throws -> Locale {
        let requested = Locale(identifier: identifier)
        if let supported = await SpeechTranscriber.supportedLocale(equivalentTo: requested) {
            return supported
        }
        let installed = await SpeechTranscriber.installedLocales
        if let match = installed.first(where: {
            $0.language.languageCode == requested.language.languageCode
        }) {
            return match
        }
        throw SubtitleTranscriptionError.localeNotInstalled
    }

    private static func extractRuns(
        from result: SpeechTranscriber.Result,
        globalOffset: TimeInterval
    ) -> [TimedTextRun] {
        var runs: [TimedTextRun] = []
        for run in result.text.runs {
            if let cmRange = run[AttributeScopes.SpeechAttributes.TimeRangeAttribute.self] {
                let text = String(result.text[run.range].characters)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                let start = CMTimeGetSeconds(cmRange.start)
                let end = CMTimeGetSeconds(cmRange.end)
                guard start.isFinite, end.isFinite, end > start else { continue }

                runs.append(
                    TimedTextRun(
                        text: text,
                        startTime: globalOffset + start,
                        endTime: globalOffset + end
                    )
                )
            }
        }

        if runs.isEmpty {
            let text = String(result.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                let start = CMTimeGetSeconds(result.range.start)
                let end = CMTimeGetSeconds(result.range.end)
                if start.isFinite, end.isFinite, end > start {
                    runs.append(
                        TimedTextRun(
                            text: text,
                            startTime: globalOffset + start,
                            endTime: globalOffset + end
                        )
                    )
                }
            }
        }

        return runs
    }
    #endif
}

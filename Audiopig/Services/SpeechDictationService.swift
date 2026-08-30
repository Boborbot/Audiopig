//
//  SpeechDictationService.swift
//  Audiopig
//

import AVFoundation
import Foundation
import Speech

@MainActor
final class SpeechDictationService: SpeechDictationServiceProtocol {
    private(set) var isRecording = false

    private let speechRecognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var onUpdate: (@MainActor (String) -> Void)?

    init(locale: Locale = .current) {
        speechRecognizer = SFSpeechRecognizer(locale: locale)
    }

    func start(onUpdate: @escaping @MainActor (String) -> Void) async throws {
        guard !isRecording else { return }
        try await requestPermissions()

        guard let speechRecognizer, speechRecognizer.isAvailable else {
            throw SpeechDictationError.recognizerUnavailable
        }

        self.onUpdate = onUpdate
        tearDownRecording()

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,
                options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw SpeechDictationError.audioSessionFailed
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if speechRecognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            tearDownRecording()
            throw SpeechDictationError.audioEngineFailed
        }

        recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, _ in
            guard let self, let result else { return }
            let transcript = result.bestTranscription.formattedString
                .trimmingCharacters(in: .whitespacesAndNewlines)
            Task { @MainActor in
                self.onUpdate?(transcript)
            }
        }

        isRecording = true
    }

    func stop() {
        tearDownRecording()
        restorePlaybackSession()
    }

    private func tearDownRecording() {
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        onUpdate = nil
    }

    private func restorePlaybackSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [])
        try? session.setActive(true)
    }

    private func requestPermissions() async throws {
        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else {
            throw SpeechDictationError.microphonePermissionDenied
        }

        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speechStatus == .authorized else {
            throw SpeechDictationError.speechPermissionDenied
        }
    }
}

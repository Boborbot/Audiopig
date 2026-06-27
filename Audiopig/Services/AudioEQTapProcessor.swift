//
//  AudioEQTapProcessor.swift
//  Audiopig
//

import AVFoundation
import MediaToolbox

/// Installs MTAudioProcessingTap on AVPlayerItem audio tracks for EQ + voice boost.
final class AudioEQTapProcessor {
    let processor = AudioEnhancementProcessor()

    private(set) var activeEQPresetID: String = SpeechEQPreset.off.id
    private(set) var voiceBoostLevel: VoiceBoostLevel = .off

    func setEQPreset(_ presetID: String) {
        let preset = SpeechEQPreset.validated(presetID)
        activeEQPresetID = preset.id
        processor.applyPreset(preset)
    }

    func setVoiceBoostLevel(_ level: VoiceBoostLevel) {
        voiceBoostLevel = level
        processor.setVoiceBoostLevel(level)
    }

    func makeAudioMix(for url: URL) -> AVAudioMix? {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else { return nil }

        var tap: MTAudioProcessingTap?
        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapCallbacksVersion_0,
            clientInfo: Unmanaged.passUnretained(processor).toOpaque(),
            init: Self.tapInit,
            finalize: Self.tapFinalize,
            prepare: Self.tapPrepare,
            unprepare: Self.tapUnprepare,
            process: Self.tapProcess
        )

        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )
        guard status == noErr, let tap else { return nil }

        let inputParameters = AVMutableAudioMixInputParameters(track: track)
        inputParameters.audioTapProcessor = tap

        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [inputParameters]
        return audioMix
    }

    // MARK: - Tap Callbacks

    private static let tapInit: MTAudioProcessingTapInitCallback = { _, clientInfo, tapStorageOut in
        tapStorageOut.pointee = clientInfo
    }

    private static let tapFinalize: MTAudioProcessingTapFinalizeCallback = { _ in }

    private static let tapPrepare: MTAudioProcessingTapPrepareCallback = { tap, _, processingFormat in
        let storage = MTAudioProcessingTapGetStorage(tap)
        let processor = Unmanaged<AudioEnhancementProcessor>.fromOpaque(storage).takeUnretainedValue()
        let sampleRate = Float(processingFormat.pointee.mSampleRate)
        processor.setSampleRate(sampleRate)
    }

    private static let tapUnprepare: MTAudioProcessingTapUnprepareCallback = { _ in }

    private static let tapProcess: MTAudioProcessingTapProcessCallback = {
        tap,
        numberFrames,
        _,
        bufferListInOut,
        numberFramesOut,
        flagsOut
    in
        let storage = MTAudioProcessingTapGetStorage(tap)
        let processor = Unmanaged<AudioEnhancementProcessor>.fromOpaque(storage).takeUnretainedValue()

        var timeRange = CMTimeRange()
        var sourceFrames = numberFrames
        let status = MTAudioProcessingTapGetSourceAudio(
            tap,
            numberFrames,
            bufferListInOut,
            flagsOut,
            &timeRange,
            &sourceFrames
        )
        guard status == noErr else { return }

        numberFramesOut.pointee = sourceFrames
        processor.process(bufferList: bufferListInOut, frameCount: Int(sourceFrames))
    }
}

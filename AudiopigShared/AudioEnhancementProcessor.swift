//
//  AudioEnhancementProcessor.swift
//  AudiopigShared
//

import CoreAudio
import Foundation

private struct ChannelEnhancementState: Sendable {
    var eqFilters: [BiquadFilter] = []
    var voiceBoost = VoiceBoostProcessor()

    mutating func configure(preset: SpeechEQPreset, sampleRate: Float) {
        eqFilters = preset.bands.map { band in
            var filter = BiquadFilter()
            filter.configure(
                kind: band.kind,
                sampleRate: sampleRate,
                frequency: band.frequency,
                q: band.q,
                gainDB: band.gainDB
            )
            return filter
        }
        voiceBoost.setSampleRate(sampleRate)
    }

    mutating func reset() {
        for index in eqFilters.indices {
            eqFilters[index].reset()
        }
        voiceBoost.reset()
    }

    mutating func mergeStatefulFields(from other: ChannelEnhancementState) {
        voiceBoost.mergeEnvelope(from: other.voiceBoost)
        let filterCount = min(eqFilters.count, other.eqFilters.count)
        for index in 0..<filterCount {
            eqFilters[index].mergeDelayState(from: other.eqFilters[index])
        }
    }

    mutating func process(_ input: Float, voiceBoostLevel: VoiceBoostLevel, bypassEQ: Bool) -> Float {
        var sample = input
        if !bypassEQ {
            for index in eqFilters.indices {
                sample = eqFilters[index].process(sample)
            }
        }
        if voiceBoostLevel.isEnabled {
            sample = voiceBoost.process(sample, maxBoost: voiceBoostLevel.maxBoost)
        }
        return sample
    }
}

/// Thread-safe audio enhancement chain used from MTAudioProcessingTap callbacks.
public final class AudioEnhancementProcessor: @unchecked Sendable {
    private var lock = NSLock()
    private var channels: [ChannelEnhancementState] = [ChannelEnhancementState(), ChannelEnhancementState()]
    private var sampleRate: Float = 44_100
    private var preset: SpeechEQPreset = .off
    private var voiceBoostLevel: VoiceBoostLevel = .off

    public init() {}

    public func setSampleRate(_ rate: Float) {
        lock.lock()
        defer { lock.unlock() }
        sampleRate = max(rate, 8_000)
        reconfigureChannelsLocked()
    }

    public func applyPreset(_ preset: SpeechEQPreset) {
        lock.lock()
        defer { lock.unlock() }
        self.preset = preset
        reconfigureChannelsLocked()
    }

    public func setVoiceBoostLevel(_ level: VoiceBoostLevel) {
        lock.lock()
        defer { lock.unlock() }
        let wasEnabled = voiceBoostLevel.isEnabled
        voiceBoostLevel = level
        if wasEnabled && !level.isEnabled {
            for index in channels.indices {
                channels[index].voiceBoost.reset()
            }
        }
    }

    public func process(bufferList: UnsafeMutablePointer<AudioBufferList>, frameCount: Int) {
        lock.lock()
        let preset = preset
        let voiceBoostLevel = voiceBoostLevel
        let bypassEQ = preset.isBypass
        var localChannels = channels
        lock.unlock()

        let buffers = UnsafeMutableAudioBufferListPointer(bufferList)
        let activeChannels = min(buffers.count, localChannels.count)

        for channelIndex in 0..<activeChannels {
            guard let data = buffers[channelIndex].mData?.assumingMemoryBound(to: Float.self) else { continue }
            for frame in 0..<frameCount {
                data[frame] = localChannels[channelIndex].process(
                    data[frame],
                    voiceBoostLevel: voiceBoostLevel,
                    bypassEQ: bypassEQ
                )
            }
        }

        lock.lock()
        let mergeCount = min(channels.count, localChannels.count)
        for index in 0..<mergeCount {
            channels[index].mergeStatefulFields(from: localChannels[index])
        }
        lock.unlock()
    }

    private func reconfigureChannelsLocked() {
        if channels.count < 2 {
            channels = [ChannelEnhancementState(), ChannelEnhancementState()]
        }
        for index in channels.indices {
            channels[index].configure(preset: preset, sampleRate: sampleRate)
            if !voiceBoostLevel.isEnabled {
                channels[index].voiceBoost.reset()
            }
        }
    }
}

struct UnsafeMutableAudioBufferListPointer: RandomAccessCollection {
    private let pointer: UnsafeMutablePointer<AudioBufferList>

    init(_ pointer: UnsafeMutablePointer<AudioBufferList>) {
        self.pointer = pointer
    }

    var count: Int { Int(pointer.pointee.mNumberBuffers) }

    subscript(index: Int) -> AudioBuffer {
        get {
            withUnsafeMutablePointer(to: &pointer.pointee.mBuffers) { base in
                base[index]
            }
        }
        set {
            withUnsafeMutablePointer(to: &pointer.pointee.mBuffers) { base in
                base[index] = newValue
            }
        }
    }

    var startIndex: Int { 0 }
    var endIndex: Int { count }
}

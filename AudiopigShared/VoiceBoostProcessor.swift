//
//  VoiceBoostProcessor.swift
//  AudiopigShared
//

import Foundation

/// Per-channel gentle loudness lift for quiet narration — avoids heavy compression or hard clipping.
public struct VoiceBoostProcessor: Sendable {
    private var envelope: Float = 0
    private var sampleRate: Float = 44_100
    private var maxBoost: Float = VoiceBoostLevel.strong.maxBoost

    public init() {}

    public mutating func setSampleRate(_ rate: Float) {
        sampleRate = max(rate, 8_000)
        reset()
    }

    public mutating func setMaxBoost(_ boost: Float) {
        maxBoost = max(1, boost)
        reset()
    }

    public mutating func reset() {
        envelope = 0
    }

    public mutating func process(_ input: Float) -> Float {
        guard maxBoost > 1 else { return input }

        let absSample = abs(input)
        let attack = exp(-1 / (0.120 * sampleRate))
        let release = exp(-1 / (0.450 * sampleRate))
        let coeff = absSample > envelope ? attack : release
        envelope = coeff * envelope + (1 - coeff) * absSample

        // Lift only quieter passages; leave normal and loud material mostly untouched.
        let quietThreshold: Float = 0.16
        let fadeThreshold: Float = 0.30

        var gain: Float = 1
        if envelope < quietThreshold {
            let quietness = 1 - min(envelope / quietThreshold, 1)
            gain = 1 + (maxBoost - 1) * quietness
        } else if envelope < fadeThreshold {
            let fade = (fadeThreshold - envelope) / (fadeThreshold - quietThreshold)
            gain = 1 + (maxBoost - 1) * fade * 0.35
        }

        var sample = input * gain

        // Soft knee above high levels — no brick-wall clipping.
        let softCeiling: Float = 0.82
        let absOutput = abs(sample)
        if absOutput > softCeiling {
            let excess = absOutput - softCeiling
            let softened = softCeiling + excess / (1 + excess * 4)
            sample = softened * (sample < 0 ? -1 : 1)
        }

        return sample
    }
}

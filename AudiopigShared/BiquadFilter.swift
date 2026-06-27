//
//  BiquadFilter.swift
//  AudiopigShared
//

import Foundation

public enum BiquadFilterKind: Sendable, Equatable {
    case highPass
    case lowPass
    case peaking
    case lowShelf
    case highShelf
}

/// Single-channel biquad IIR filter (RBJ audio EQ cookbook).
public struct BiquadFilter: Sendable {
    private var b0: Float = 1
    private var b1: Float = 0
    private var b2: Float = 0
    private var a1: Float = 0
    private var a2: Float = 0
    private var z1: Float = 0
    private var z2: Float = 0

    public init() {}

    public mutating func reset() {
        z1 = 0
        z2 = 0
    }

    public mutating func mergeDelayState(from other: BiquadFilter) {
        z1 = other.z1
        z2 = other.z2
    }

    public mutating func configure(
        kind: BiquadFilterKind,
        sampleRate: Float,
        frequency: Float,
        q: Float,
        gainDB: Float
    ) {
        let nyquist = sampleRate * 0.5
        let f = min(max(frequency, 20), nyquist * 0.99)
        let w0 = 2 * Float.pi * f / sampleRate
        let cosW0 = cos(w0)
        let sinW0 = sin(w0)
        let alpha = sinW0 / (2 * max(q, 0.1))
        let a = pow(10, gainDB / 40)

        var nb0: Float = 0
        var nb1: Float = 0
        var nb2: Float = 0
        var na0: Float = 1
        var na1: Float = 0
        var na2: Float = 0

        switch kind {
        case .highPass:
            nb0 = (1 + cosW0) / 2
            nb1 = -(1 + cosW0)
            nb2 = (1 + cosW0) / 2
            na0 = 1 + alpha
            na1 = -2 * cosW0
            na2 = 1 - alpha
        case .lowPass:
            nb0 = (1 - cosW0) / 2
            nb1 = 1 - cosW0
            nb2 = (1 - cosW0) / 2
            na0 = 1 + alpha
            na1 = -2 * cosW0
            na2 = 1 - alpha
        case .peaking:
            nb0 = 1 + alpha * a
            nb1 = -2 * cosW0
            nb2 = 1 - alpha * a
            na0 = 1 + alpha / a
            na1 = -2 * cosW0
            na2 = 1 - alpha / a
        case .lowShelf:
            let sqrtA = sqrt(a)
            nb0 = a * ((a + 1) - (a - 1) * cosW0 + 2 * sqrtA * alpha)
            nb1 = 2 * a * ((a - 1) - (a + 1) * cosW0)
            nb2 = a * ((a + 1) - (a - 1) * cosW0 - 2 * sqrtA * alpha)
            na0 = (a + 1) + (a - 1) * cosW0 + 2 * sqrtA * alpha
            na1 = -2 * ((a - 1) + (a + 1) * cosW0)
            na2 = (a + 1) + (a - 1) * cosW0 - 2 * sqrtA * alpha
        case .highShelf:
            let sqrtA = sqrt(a)
            nb0 = a * ((a + 1) + (a - 1) * cosW0 + 2 * sqrtA * alpha)
            nb1 = -2 * a * ((a - 1) + (a + 1) * cosW0)
            nb2 = a * ((a + 1) + (a - 1) * cosW0 - 2 * sqrtA * alpha)
            na0 = (a + 1) - (a - 1) * cosW0 + 2 * sqrtA * alpha
            na1 = 2 * ((a - 1) - (a + 1) * cosW0)
            na2 = (a + 1) - (a - 1) * cosW0 - 2 * sqrtA * alpha
        }

        b0 = nb0 / na0
        b1 = nb1 / na0
        b2 = nb2 / na0
        a1 = na1 / na0
        a2 = na2 / na0
        reset()
    }

    public mutating func process(_ input: Float) -> Float {
        let output = b0 * input + z1
        z1 = b1 * input - a1 * output + z2
        z2 = b2 * input - a2 * output
        return output
    }
}

//
//  SubtitleCueTiming.swift
//  AudiopigShared
//

import Foundation

/// A single display line of subtitles on the global book timeline.
public struct SubtitleCueTiming: Sendable, Equatable {
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let text: String
    public let orderIndex: Int

    public init(
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        orderIndex: Int
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.orderIndex = orderIndex
    }
}

/// Record of audio submitted to on-device ASR (independent of cue density).
public struct SubtitleTranscriptionSegmentTiming: Sendable, Equatable {
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(startTime: TimeInterval, endTime: TimeInterval) {
        self.startTime = startTime
        self.endTime = endTime
    }

    public var duration: TimeInterval {
        max(0, endTime - startTime)
    }
}

/// A timed slice of audio on the global book timeline to transcribe.
public struct SubtitleTimeWindow: Sendable, Equatable {
    public let globalStart: TimeInterval
    public let globalEnd: TimeInterval

    public init(globalStart: TimeInterval, globalEnd: TimeInterval) {
        self.globalStart = globalStart
        self.globalEnd = globalEnd
    }

    public var duration: TimeInterval {
        max(0, globalEnd - globalStart)
    }

    public func overlaps(_ other: SubtitleTimeWindow) -> Bool {
        globalStart < other.globalEnd && globalEnd > other.globalStart
    }

    public func contains(_ time: TimeInterval) -> Bool {
        time >= globalStart && time < globalEnd
    }
}

/// Word- or segment-level timing before grouping into display lines.
public struct TimedTextRun: Sendable, Equatable {
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval

    public init(text: String, startTime: TimeInterval, endTime: TimeInterval) {
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
    }
}

//
//  AudioEngineError.swift
//  Audiopig
//

import Foundation

enum AudioEngineError: Error, Equatable, Sendable {
    case noLoadedAudiobook
    case loadFailed
    case seekFailed
    case playbackFailed
    case backgroundAudioConfigurationFailed
}

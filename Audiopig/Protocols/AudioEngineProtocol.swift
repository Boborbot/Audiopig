//
//  AudioEngineProtocol.swift
//  Audiopig
//

import AVFoundation
import Combine
import Foundation

/// Manages AVPlayer lifecycle, global timeline resolution, playback state, and background audio session.
@MainActor
protocol AudioEngineProtocol: AnyObject {

    // MARK: - Synchronous State

    var playbackState: PlaybackState { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var playbackSpeed: Float { get }
    var loadedAudiobookID: UUID? { get }

    // MARK: - Combine Observation

    /// Emits the current global timeline position at ~0.5 s intervals during playback.
    var currentTimePublisher: AnyPublisher<TimeInterval, Never> { get }

    /// Emits every time the engine transitions between playback states.
    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> { get }

    // MARK: - Lifecycle

    /// Loads an audiobook, resolves its chapter playlist, and seeks to the stored resume position.
    func load(audiobook: Audiobook) async throws

    /// Unloads the current audiobook and resets all state to idle.
    func unload()

    // MARK: - Transport

    func play() throws
    func pause()

    /// Seeks to an absolute position on the global timeline.
    /// Cross-chapter seeks transparently load the correct source file.
    func seek(to globalTime: TimeInterval) async throws

    /// Jumps forward by `seconds` from the current position.
    func skipForward(by seconds: TimeInterval) async throws

    /// Jumps backward by `seconds` from the current position.
    func skipBackward(by seconds: TimeInterval) async throws

    /// Sets the playback rate. Clamped to [0.5, 3.0].
    func setPlaybackSpeed(_ speed: Float) throws

    /// Updates the lock-screen skip-forward and skip-backward intervals for the remote command center.
    func updateRemoteSkipIntervals(forward: TimeInterval, backward: TimeInterval)
}

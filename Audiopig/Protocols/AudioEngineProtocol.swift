//
//  AudioEngineProtocol.swift
//  Audiopig
//

import AVFoundation
import Combine
import Foundation

/// Whether lock-screen elapsed/duration reflect the whole book or the active chapter.
enum NowPlayingTimelineScope: Equatable {
    case entireBook
    case currentChapter
}

/// Manages AVPlayer lifecycle, global timeline resolution, playback state, and background audio session.
@MainActor
protocol AudioEngineProtocol: AnyObject {

    // MARK: - Synchronous State

    var playbackState: PlaybackState { get }
    var currentTime: TimeInterval { get }
    var duration: TimeInterval { get }
    var playbackSpeed: Float { get }
    var loadedAudiobookID: UUID? { get }

    /// Ordered, immutable snapshots of all chapters in the currently loaded book.
    /// Used by LullDetector to map file URLs and global offsets without re-reading SwiftData.
    var resolvedChapters: [ResolvedChapter] { get }

    /// When `false`, reaching the end of a chapter file pauses instead of loading the next chapter.
    var shouldAutoAdvanceAtChapterEnd: Bool { get set }

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

    /// Refreshes resolved chapter snapshots after the user edits chapter metadata
    /// without tearing down the active AVPlayerItem.
    func updateResolvedChapters(from audiobook: Audiobook)

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

    /// Active speech EQ preset identifier.
    var activeEQPresetID: String { get }

    /// Active Voice Boost level. `.off` bypasses loudness processing.
    var voiceBoostLevel: VoiceBoostLevel { get }

    /// Applies a speech EQ preset to live playback.
    func setEQPreset(_ presetID: String) throws

    /// Sets Voice Boost loudness processing intensity.
    func setVoiceBoostLevel(_ level: VoiceBoostLevel) throws

    /// Updates the lock-screen skip-forward and skip-backward intervals for the remote command center.
    func updateRemoteSkipIntervals(forward: TimeInterval, backward: TimeInterval)

    /// Scopes lock-screen elapsed time and duration to the whole book or the active chapter.
    func setNowPlayingTimelineScope(_ scope: NowPlayingTimelineScope)
}

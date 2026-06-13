//
//  AudioEngine.swift
//  Audiopig
//
//  Manages AVPlayer across a multi-file virtual audiobook timeline.
//
//  Design notes:
//  - Chapter data is snapshotted into ResolvedChapter value types at load time so that
//    live SwiftData mutations never corrupt the in-flight playlist.
//  - Every public state mutation goes through CurrentValueSubject, giving ViewModels
//    Combine-based observation without any coupling to the concrete class.
//  - Cross-chapter transitions are driven by AVPlayerItemDidPlayToEndTime so there is
//    no polling and no gap in the audio stream beyond the file-load latency.
//  - NOTE: Background audio requires the "Audio, AirPlay, and Picture in Picture"
//    capability and the UIBackgroundModes audio key in Info.plist.
//

import AVFoundation
import Combine
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class AudioEngine: AudioEngineProtocol {

    // MARK: - AudioEngineProtocol — Public State

    var playbackState: PlaybackState { _playbackState.value }
    var currentTime: TimeInterval { _currentTime.value }
    var duration: TimeInterval { _loadedDuration }
    var playbackSpeed: Float { _playbackSpeed }
    var loadedAudiobookID: UUID? { _loadedAudiobookID }

    var currentTimePublisher: AnyPublisher<TimeInterval, Never> {
        _currentTime.eraseToAnyPublisher()
    }

    var playbackStatePublisher: AnyPublisher<PlaybackState, Never> {
        _playbackState.eraseToAnyPublisher()
    }

    // MARK: - Private Subjects

    private let _currentTime = CurrentValueSubject<TimeInterval, Never>(0)
    private let _playbackState = CurrentValueSubject<PlaybackState, Never>(.idle)

    // MARK: - Private Playback State

    private let player: AVPlayer = AVPlayer()
    private var resolvedChapters: [ResolvedChapter] = []
    private var fileGlobalOffsets: [URL: TimeInterval] = [:]
    private var currentChapterIndex: Int = 0
    private var _loadedAudiobookID: UUID?
    private var _loadedDuration: TimeInterval = 0
    private var _playbackSpeed: Float = 1.0

    // MARK: - Private Observers

    private var timeObserverToken: Any?
    private var itemEndObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    /// Stores the current AVPlayerItem status observation so it stays alive until resolved.
    private var playerItemStatusObservation: NSKeyValueObservation?
    /// Guards against the KVO callback firing more than once per item load.
    private var itemReadinessResumed: Bool = false

    // MARK: - Now Playing Snapshot (set at load time, read by observer callbacks)

    private var _nowPlayingTitle: String = ""
    private var _nowPlayingAuthor: String = ""
    private var _nowPlayingArtwork: MPMediaItemArtwork?

    // MARK: - Remote Skip Intervals (updated via updateRemoteSkipIntervals)

    private var _remoteSkipForwardInterval: TimeInterval = 15
    private var _remoteSkipBackwardInterval: TimeInterval = 15

    // MARK: - Init / Deinit

    init() throws {
        try configureAudioSession()
        installEndObserver()
        installAudioSessionObservers()
        setupRemoteCommandCenter()
    }

    deinit {
        if let observer = itemEndObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = interruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        // timeObserverToken: the periodic observer uses [weak self] so after dealloc
        // no callbacks fire; formal removal requires main-thread access to `player`
        // which is guaranteed here because AudioEngine is @MainActor and deinit runs
        // on the last-releasing thread — in practice always main for UI-owned objects.
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    // MARK: - AudioEngineProtocol — Lifecycle

    func load(audiobook: Audiobook) async throws {
        let chapters = audiobook.chapters
        guard !chapters.isEmpty else {
            throw AudioEngineError.loadFailed
        }

        tearDownCurrentPlayback()

        let snapshots = chapters
            .sorted { $0.orderIndex < $1.orderIndex }
            .map(ResolvedChapter.init(from:))

        resolvedChapters = snapshots
        // Build a URL → earliest-startTime map once so the time observer and seek
        // logic can look up the file-global offset in O(1) instead of scanning every tick.
        var offsets: [URL: TimeInterval] = [:]
        for chapter in snapshots {
            if let existing = offsets[chapter.fileURL] {
                if chapter.startTime < existing { offsets[chapter.fileURL] = chapter.startTime }
            } else {
                offsets[chapter.fileURL] = chapter.startTime
            }
        }
        fileGlobalOffsets = offsets

        _loadedAudiobookID = audiobook.id
        _loadedDuration = audiobook.duration
        _playbackState.send(.loading)

        _nowPlayingTitle = audiobook.title
        _nowPlayingAuthor = audiobook.author
        _nowPlayingArtwork = audiobook.coverArtwork.flatMap { data in
            guard let image = UIImage(data: data) else { return nil }
            return MPMediaItemArtwork(boundsSize: image.size) { _ in image }
        }

        let resumeTime = max(0, min(audiobook.currentPlaybackTime, audiobook.duration))

        guard let startIndex = chapterIndex(forGlobalTime: resumeTime) else {
            throw AudioEngineError.loadFailed
        }

        let localOffset = resumeTime - snapshots[startIndex].startTime

        // loadChapter is non-blocking for item readiness; failures surface via .failed state.
        // It can still throw synchronously for an invalid index, so keep the do/catch.
        do {
            try await loadChapter(at: startIndex, seekingToLocalOffset: max(0, localOffset), autoPlay: false)
        } catch {
            _playbackState.send(.failed(message: "Could not load audiobook."))
            throw error
        }
    }

    func unload() {
        tearDownCurrentPlayback()
        resolvedChapters = []
        _loadedAudiobookID = nil
        _loadedDuration = 0
        _playbackSpeed = 1.0
        _currentTime.send(0)
        _playbackState.send(.idle)
        _nowPlayingTitle = ""
        _nowPlayingAuthor = ""
        _nowPlayingArtwork = nil
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - AudioEngineProtocol — Transport

    func play() throws {
        guard _loadedAudiobookID != nil else { throw AudioEngineError.noLoadedAudiobook }
        guard player.currentItem != nil else { throw AudioEngineError.playbackFailed }

        player.rate = _playbackSpeed
        _playbackState.send(.playing)
        updateNowPlayingInfo(elapsedTime: _currentTime.value)
    }

    func pause() {
        player.pause()
        guard case .playing = _playbackState.value else { return }
        _playbackState.send(.paused)
        updateNowPlayingInfo(elapsedTime: _currentTime.value)
    }

    func seek(to globalTime: TimeInterval) async throws {
        guard _loadedAudiobookID != nil else { throw AudioEngineError.noLoadedAudiobook }

        let clamped = max(0, min(globalTime, _loadedDuration))

        guard let targetIndex = chapterIndex(forGlobalTime: clamped) else {
            throw AudioEngineError.seekFailed
        }

        let targetChapter = resolvedChapters[targetIndex]
        let localOffset   = clamped - targetChapter.startTime
        let wasPlaying    = _playbackState.value == .playing

        // The branching criterion is whether the PHYSICAL FILE changes, not the chapter
        // index. For single-file M4B audiobooks every chapter shares the same fileURL, so
        // inter-chapter jumps must stay within the current AVPlayerItem — creating a new
        // one would reset playback to file position 0.
        let currentFileURL = resolvedChapters[safe: currentChapterIndex]?.fileURL
        if currentFileURL == targetChapter.fileURL {
            // Same physical file: update the chapter cursor and seek within the current item.
            currentChapterIndex = targetIndex
            let fst = fileSeekTime(forGlobalTime: clamped, inChapterAt: targetIndex)
            let cmTime = CMTime(seconds: fst, preferredTimescale: 600)
            await player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
            _currentTime.send(clamped)
            updateNowPlayingInfo(elapsedTime: clamped)
        } else {
            // Different file: load the new AVPlayerItem and seek inside it.
            try await loadChapter(
                at: targetIndex,
                seekingToLocalOffset: localOffset,
                autoPlay: wasPlaying
            )
        }
    }

    func skipForward(by seconds: TimeInterval) async throws {
        try await seek(to: _currentTime.value + seconds)
    }

    func skipBackward(by seconds: TimeInterval) async throws {
        try await seek(to: _currentTime.value - seconds)
    }

    func setPlaybackSpeed(_ speed: Float) throws {
        guard _loadedAudiobookID != nil else { throw AudioEngineError.noLoadedAudiobook }

        let clamped = (0.5 ... 3.0).clamp(speed)
        _playbackSpeed = clamped

        if _playbackState.value == .playing {
            player.rate = clamped
        }

        updateNowPlayingInfo(elapsedTime: _currentTime.value)
    }

    // MARK: - Private — Chapter Loading

    /// Sets up the AVPlayerItem and returns immediately without blocking on readiness.
    ///
    /// Item readiness is observed via a stored `NSKeyValueObservation` so KVO callbacks
    /// can fire on AVFoundation's internal queue without touching the Combine/async bridge
    /// (which deadlocks under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`).
    /// The seek to `localOffset` and any failure are handled inside `handleItemReadiness`.
    private func loadChapter(
        at index: Int,
        seekingToLocalOffset localOffset: TimeInterval,
        autoPlay: Bool
    ) async throws {
        guard let chapter = resolvedChapters[safe: index] else {
            _playbackState.send(.failed(message: "Invalid chapter index."))
            throw AudioEngineError.loadFailed
        }

        // Compute where to seek INSIDE the physical file.
        // For single-file M4B every chapter's global startTime equals its file position,
        // so fst == chapter.startTime + localOffset == the global seek time.
        // For merged multi-file books each chapter lives in its own file (position 0),
        // so fst == localOffset (same as before).
        // For the rare case of merged multi-chapter files the first chapter with this
        // URL anchors the file's global offset and everything else falls out correctly.
        let globalSeekTime = chapter.startTime + localOffset
        let fst = fileSeekTime(forGlobalTime: globalSeekTime, inChapterAt: index)

        print("[AudioEngine] Loading: \(chapter.fileURL.lastPathComponent) — fileSeek \(String(format: "%.1f", fst))s (global \(String(format: "%.1f", globalSeekTime))s)")
        print("[AudioEngine] File exists: \(FileManager.default.fileExists(atPath: chapter.fileURL.path))")

        currentChapterIndex = index
        removeTimeObserver()

        // Cancel any in-flight status observation from the previous item.
        playerItemStatusObservation?.invalidate()
        playerItemStatusObservation = nil
        itemReadinessResumed = false

        player.pause()

        let item = AVPlayerItem(url: chapter.fileURL)
        player.replaceCurrentItem(with: item)

        // Snap the UI to the target global time immediately and refresh Now Playing.
        installTimeObserver()
        _currentTime.send(globalSeekTime)
        updateNowPlayingInfo(elapsedTime: globalSeekTime)

        if autoPlay {
            player.rate = _playbackSpeed
            _playbackState.send(.playing)
        } else {
            _playbackState.send(.paused)
        }

        // KVO fires on AVFoundation's internal thread; dispatch to main before
        // touching any @MainActor-isolated properties.
        playerItemStatusObservation = item.observe(\.status, options: [.new, .initial]) { [weak self] observedItem, _ in
            DispatchQueue.main.async { [weak self] in
                self?.handleItemReadiness(observedItem, fileSeekTime: fst, autoPlay: autoPlay)
            }
        }
    }

    private func handleItemReadiness(
        _ item: AVPlayerItem,
        fileSeekTime fst: TimeInterval,
        autoPlay: Bool
    ) {
        switch item.status {
        case .readyToPlay:
            // Guard against .initial delivering .unknown, or duplicate .readyToPlay fires.
            guard !itemReadinessResumed else { return }
            itemReadinessResumed = true
            playerItemStatusObservation?.invalidate()
            playerItemStatusObservation = nil
            print("[AudioEngine] Item ready.")

            guard fst > 0 else { return }

            // Seek to the file-local position now that the item can accept seeks.
            let cmTime = CMTime(seconds: fst, preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                guard let self, autoPlay else { return }
                // Re-assert rate after seek in case AVPlayer reset it to 0.
                self.player.rate = self._playbackSpeed
            }

        case .failed:
            guard !itemReadinessResumed else { return }
            itemReadinessResumed = true
            playerItemStatusObservation?.invalidate()
            playerItemStatusObservation = nil
            let desc = item.error?.localizedDescription ?? "Unknown AVPlayer error"
            print("[AudioEngine] Item FAILED: \(desc)")
            _playbackState.send(.failed(message: desc))

        default:
            // .unknown — AVFoundation is still preparing; wait for the next callback.
            break
        }
    }

    // MARK: - Private — Chapter End Handling

    private func handleChapterEnd() async {
        let nextIndex = currentChapterIndex + 1

        guard nextIndex < resolvedChapters.count else {
            _currentTime.send(_loadedDuration)
            _playbackState.send(.finished)
            return
        }

        do {
            try await loadChapter(at: nextIndex, seekingToLocalOffset: 0, autoPlay: true)
        } catch {
            _playbackState.send(.failed(message: "Chapter transition failed."))
        }
    }

    // MARK: - Private — Observer Installation

    private func installTimeObserver() {
        removeTimeObserver()

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { [weak self] time in
            guard let self else { return }
            let localSeconds = CMTimeGetSeconds(time)
            guard localSeconds.isFinite, localSeconds >= 0 else { return }
            // fileGlobalOffset is the global timeline position at which the PHYSICAL FILE
            // begins. Looked up from the precomputed map — O(1) instead of O(n) per tick.
            let fileGlobalOffset: TimeInterval = {
                guard let chapter = self.resolvedChapters[safe: self.currentChapterIndex] else { return 0 }
                return self.fileGlobalOffsets[chapter.fileURL] ?? 0
            }()
            self._currentTime.send(fileGlobalOffset + localSeconds)
            // Now Playing elapsed time is NOT updated here; the system extrapolates position
            // automatically from the rate set at play/pause/seek. Updates only happen at
            // state transitions (play, pause, seek, speed change, chapter load).
        }
    }

    private func removeTimeObserver() {
        guard let token = timeObserverToken else { return }
        player.removeTimeObserver(token)
        timeObserverToken = nil
    }

    private func installEndObserver() {
        itemEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let endedItem = notification.object as? AVPlayerItem,
                  endedItem === self.player.currentItem else { return }
            Task { @MainActor [weak self] in
                await self?.handleChapterEnd()
            }
        }
    }

    // MARK: - Private — Teardown

    private func tearDownCurrentPlayback() {
        removeTimeObserver()
        playerItemStatusObservation?.invalidate()
        playerItemStatusObservation = nil
        itemReadinessResumed = false
        player.pause()
        player.replaceCurrentItem(with: nil)
        currentChapterIndex = 0
        fileGlobalOffsets = [:]
    }

    // MARK: - Private — Chapter Resolution

    /// Returns the seek position **inside the physical file** for a given global playback time.
    ///
    /// Three book layouts are handled transparently:
    /// - **Single-file M4B** (all chapters share one URL): the file timeline equals the
    ///   global timeline, so `fileSeekTime = globalTime − 0 = globalTime`.
    /// - **Merged separate-file book** (each chapter = its own file): the chapter's file
    ///   starts at position 0, so `fileSeekTime = globalTime − chapter.startTime = localOffset`.
    /// - **Merged multi-chapter file** (rare): the first chapter anchors the file's global
    ///   offset and subsequent chapters in the same file get their correct in-file position.
    private func fileSeekTime(forGlobalTime globalTime: TimeInterval, inChapterAt index: Int) -> TimeInterval {
        guard let chapter = resolvedChapters[safe: index] else { return 0 }
        let fileGlobalOffset = fileGlobalOffsets[chapter.fileURL] ?? chapter.startTime
        return max(0, globalTime - fileGlobalOffset)
    }

    /// Binary search: returns the index of the chapter whose time range contains `globalTime`.
    /// Ties at an exact chapter boundary resolve to the later chapter.
    private func chapterIndex(forGlobalTime globalTime: TimeInterval) -> Int? {
        guard !resolvedChapters.isEmpty else { return nil }

        var low = 0
        var high = resolvedChapters.count - 1

        while low <= high {
            let mid = (low + high) / 2
            let chapter = resolvedChapters[mid]
            let end = chapter.startTime + chapter.duration

            if globalTime >= chapter.startTime && globalTime < end {
                return mid
            } else if globalTime < chapter.startTime {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }

        // `globalTime` equals exactly `_loadedDuration` → clamp to the final chapter.
        return resolvedChapters.count - 1
    }

    // MARK: - Private — Audio Session Events (interruptions & route changes)

    private func installAudioSessionObservers() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleInterruption(notification)
            }
        }

        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleRouteChange(notification)
            }
        }
    }

    /// Pauses on interruption begin; resumes on end only when the system says it's safe.
    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            pause()
        case .ended:
            let optionsValue = (info[AVAudioSessionInterruptionOptionKey] as? UInt) ?? 0
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
            if options.contains(.shouldResume) {
                try? play()
            }
        @unknown default:
            break
        }
    }

    /// Pauses when a connected audio output (headphones, BT) is pulled away.
    private func handleRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue),
              reason == .oldDeviceUnavailable else { return }

        pause()
    }

    // MARK: - Private — Remote Command Center

    func updateRemoteSkipIntervals(forward: TimeInterval, backward: TimeInterval) {
        _remoteSkipForwardInterval = forward
        _remoteSkipBackwardInterval = backward
        let center = MPRemoteCommandCenter.shared()
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: forward)]
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: backward)]
    }

    /// Registers handlers for hardware/software transport controls (lock screen, headphones,
    /// CarPlay, etc.). Called once at init; tokens are discarded because AudioEngine lives
    /// for the app's lifetime and we never need to deregister.
    private func setupRemoteCommandCenter() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in try? self?.play() }
            return .success
        }

        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }

        center.skipForwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: _remoteSkipForwardInterval)]
        center.skipForwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await self.skipForward(by: self._remoteSkipForwardInterval)
            }
            return .success
        }

        center.skipBackwardCommand.isEnabled = true
        center.skipBackwardCommand.preferredIntervals = [NSNumber(value: _remoteSkipBackwardInterval)]
        center.skipBackwardCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                try? await self.skipBackward(by: self._remoteSkipBackwardInterval)
            }
            return .success
        }

        // Lock-screen scrubber — maps the timeline slider directly to seek().
        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let posEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor [weak self] in try? await self?.seek(to: posEvent.positionTime) }
            return .success
        }

        // Disable commands we don't expose so the lock screen stays uncluttered.
        center.nextTrackCommand.isEnabled = false
        center.previousTrackCommand.isEnabled = false
        center.changePlaybackRateCommand.isEnabled = false
    }

    // MARK: - Private — Now Playing Info

    /// Pushes a full now-playing dictionary to the system.
    ///
    /// `elapsedTime` is the current global timeline position. The system extrapolates
    /// forward using `MPNowPlayingInfoPropertyPlaybackRate`, so lock-screen time stays
    /// accurate without needing sub-second updates.
    private func updateNowPlayingInfo(elapsedTime: TimeInterval) {
        guard !_nowPlayingTitle.isEmpty else { return }

        let rate = _playbackState.value == .playing ? Double(_playbackSpeed) : 0.0

        var info: [String: Any] = [
            MPMediaItemPropertyTitle:                   _nowPlayingTitle,
            MPMediaItemPropertyArtist:                  _nowPlayingAuthor,
            MPMediaItemPropertyPlaybackDuration:        _loadedDuration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsedTime,
            MPNowPlayingInfoPropertyPlaybackRate:        rate,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: Double(_playbackSpeed),
            MPNowPlayingInfoPropertyMediaType:           MPNowPlayingInfoMediaType.audio.rawValue,
        ]

        if let artwork = _nowPlayingArtwork {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Private — AVAudioSession

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            throw AudioEngineError.backgroundAudioConfigurationFailed
        }
    }
}

// MARK: - ClosedRange clamping helper

private extension ClosedRange where Bound: Comparable {
    func clamp(_ value: Bound) -> Bound {
        Swift.min(upperBound, Swift.max(lowerBound, value))
    }
}

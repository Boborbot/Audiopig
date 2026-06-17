//
//  WatchAudioEngine.swift
//  AudiopigWatch
//

import AVFoundation
import Foundation

@MainActor
final class WatchAudioEngine {
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?

    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var playbackSpeed: Float = 1.0
    private(set) var playbackState: WatchPlaybackState = .idle
    private(set) var loadedBookID: UUID?

    var onTimeUpdate: ((TimeInterval) -> Void)?
    var onStateChange: ((WatchPlaybackState) -> Void)?

    func load(url: URL, bookID: UUID, startTime: TimeInterval, duration: TimeInterval, autoPlay: Bool) {
        tearDownObservers()
        loadedBookID = bookID
        self.duration = duration
        currentTime = startTime
        playbackState = .loading
        onStateChange?(.loading)

        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.pause()

        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch item.status {
                case .readyToPlay:
                    await self.seek(to: startTime, autoPlay: autoPlay)
                case .failed:
                    self.playbackState = .failed(message: "Could not load audiobook.")
                    self.onStateChange?(self.playbackState)
                default:
                    break
                }
            }
        }
        installObservers(for: item)
    }

    func play() {
        guard loadedBookID != nil else { return }
        player.rate = playbackSpeed
        playbackState = .playing
        onStateChange?(.playing)
    }

    func pause() {
        player.pause()
        guard playbackState == .playing else { return }
        playbackState = .paused
        onStateChange?(.paused)
    }

    func togglePlayPause() {
        if playbackState == .playing {
            pause()
        } else {
            play()
        }
    }

    func setSpeed(_ speed: Float) {
        let clamped = min(WatchSpeedRange.max, max(WatchSpeedRange.min, speed))
        playbackSpeed = clamped
        if playbackState == .playing {
            player.rate = clamped
        }
    }

    func setVolume(_ volume: Float) {
        player.volume = max(0, min(1, volume))
    }

    func skip(by delta: TimeInterval) async {
        await seek(to: currentTime + delta, autoPlay: playbackState == .playing)
    }

    func seek(to globalTime: TimeInterval, autoPlay: Bool) async {
        let clamped = max(0, min(globalTime, duration))
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        await player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = clamped
        onTimeUpdate?(clamped)
        if autoPlay {
            play()
        } else if playbackState != .loading {
            playbackState = .paused
            onStateChange?(.paused)
        }
    }

    func unload() {
        tearDownObservers()
        player.replaceCurrentItem(with: nil)
        loadedBookID = nil
        duration = 0
        currentTime = 0
        playbackSpeed = 1.0
        playbackState = .idle
        onStateChange?(.idle)
    }

    var systemVolume: Float {
        player.volume
    }

    // MARK: - Private

    private func installObservers(for item: AVPlayerItem) {
        let interval = CMTime(seconds: 1.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self, self.playbackState == .playing else { return }
            let seconds = CMTimeGetSeconds(time)
            guard seconds.isFinite else { return }
            self.currentTime = seconds
            self.onTimeUpdate?(seconds)
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.playbackState = .finished
            self.onStateChange?(.finished)
        }
    }

    private func tearDownObservers() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        statusObservation?.invalidate()
        statusObservation = nil
    }
}

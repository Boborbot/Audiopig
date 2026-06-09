//
//  PlayerViewModel.swift
//  Audiopig
//
//  Design notes:
//  - Engine observation uses Combine publishers bridged through .receive(on: RunLoop.main)
//    so all mutations happen on the MainActor without needing explicit async hops.
//  - isScrubbing gates engine-driven time updates: while the user drags the slider,
//    scrubPosition and the display strings are driven locally for zero-latency feedback.
//    seek is committed once on drag-end via commitScrub().
//

import Combine
import Observation
import Foundation
import SwiftData
import UIKit

@MainActor
@Observable
final class PlayerViewModel {

    // MARK: - Displayed State

    private(set) var playbackState: PlaybackState = .idle
    private(set) var playbackSpeed: Float = 1.0

    /// Elapsed time string, e.g. "1:04:32". Updated from engine every 0.5 s.
    private(set) var displayCurrentTime: String = "0:00"

    /// Remaining time string, e.g. "-2:11:05". Updated from engine every 0.5 s.
    private(set) var displayRemainingTime: String = "-0:00"

    // MARK: - Scrubbing

    /// Normalised position [0, 1] bound directly to the Slider.
    var scrubPosition: Double = 0

    /// True while the user is actively dragging the scrubber.
    private(set) var isScrubbing: Bool = false

    // MARK: - Displayed Audiobook

    private(set) var audiobook: Audiobook?

    // MARK: - Chapters

    /// Controls the chapters sheet presented from PlayerView.
    var isChaptersPresented: Bool = false

    /// Chapters of the current audiobook sorted by play order.
    var chapters: [Chapter] {
        audiobook?.chapters.sorted { $0.orderIndex < $1.orderIndex } ?? []
    }

    /// Index into `chapters` for the chapter that contains the current playback position.
    /// Kept as a stored property so @Observable tracks it and the sheet updates reactively.
    private(set) var currentChapterIndex: Int = 0

    // MARK: - Speed Options

    static let availableSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    var speedLabel: String {
        let f = playbackSpeed
        return f.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(f))×"
            : String(format: "%.2g×", f)
    }

    /// True whenever an audiobook is loaded into the engine (even while loading/paused).
    /// Drives MiniPlayer visibility.
    var isActive: Bool { audiobook != nil }

    var playPauseImage: String {
        if case .playing = playbackState { return "pause.fill" }
        return "play.fill"
    }

    // MARK: - Computed display during scrub

    /// Elapsed time accounting for active scrub position.
    var scrubDisplayCurrentTime: String {
        isScrubbing ? Self.formatTime(scrubPosition * audioEngine.duration) : displayCurrentTime
    }

    /// Remaining time accounting for active scrub position.
    var scrubDisplayRemainingTime: String {
        guard isScrubbing else { return displayRemainingTime }
        let t = scrubPosition * audioEngine.duration
        return "-\(Self.formatTime(max(0, audioEngine.duration - t)))"
    }

    // MARK: - Private

    private let audioEngine: any AudioEngineProtocol
    private let modelContext: ModelContext

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var positionSaveTimer: AnyCancellable?

    // MARK: - Init

    init(audioEngine: any AudioEngineProtocol, modelContext: ModelContext) {
        self.audioEngine = audioEngine
        self.modelContext = modelContext
        observeEngine()
        startPositionSaveTimer()
        installBackgroundObserver()
    }

    // MARK: - Lifecycle

    func loadAudiobook(_ audiobook: Audiobook, autoPlay: Bool = false) async {
        self.audiobook = audiobook
        do {
            try await audioEngine.load(audiobook: audiobook)
            if autoPlay { try? audioEngine.play() }
        } catch {
            playbackState = .failed(message: "Could not load \"\(audiobook.title)\".")
        }
    }

    // MARK: - Transport

    func togglePlayPause() {
        switch playbackState {
        case .playing:
            audioEngine.pause()
        case .paused, .finished, .idle:
            try? audioEngine.play()
        case .loading, .failed:
            break
        }
    }

    func skipForward() {
        Task { try? await audioEngine.skipForward(by: 15) }
    }

    func skipBackward() {
        Task { try? await audioEngine.skipBackward(by: 15) }
    }

    func setSpeed(_ speed: Float) {
        try? audioEngine.setPlaybackSpeed(speed)
        playbackSpeed = audioEngine.playbackSpeed
    }

    func seekToChapter(_ chapter: Chapter) {
        isChaptersPresented = false
        Task { try? await audioEngine.seek(to: chapter.startTime) }
    }

    // MARK: - Scrubbing

    func beginScrubbing() {
        isScrubbing = true
    }

    func commitScrub() async {
        let targetTime = scrubPosition * audioEngine.duration
        isScrubbing = false
        try? await audioEngine.seek(to: targetTime)
    }

    // MARK: - Private — Engine Observation

    private func observeEngine() {
        audioEngine.currentTimePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                guard let self, !self.isScrubbing else { return }
                self.applyEngineTime(time)
            }
            .store(in: &cancellables)

        audioEngine.playbackStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.playbackState = state
                self.playbackSpeed = self.audioEngine.playbackSpeed

                // Persist position any time playback stops naturally or by user action.
                switch state {
                case .paused, .finished:
                    self.savePlaybackPosition()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func applyEngineTime(_ time: TimeInterval) {
        let duration = audioEngine.duration
        scrubPosition = duration > 0 ? min(1, time / duration) : 0
        displayCurrentTime = Self.formatTime(time)
        displayRemainingTime = "-\(Self.formatTime(max(0, duration - time)))"
        currentChapterIndex = resolveChapterIndex(for: time)
    }

    private func resolveChapterIndex(for time: TimeInterval) -> Int {
        let chaps = chapters
        for (i, chapter) in chaps.enumerated() {
            if time >= chapter.startTime && time < chapter.startTime + chapter.duration {
                return i
            }
        }
        return max(0, chaps.count - 1)
    }

    // MARK: - Private — Persistence

    /// Writes the current engine position back to the SwiftData model and saves.
    private func savePlaybackPosition() {
        guard let audiobook else { return }
        audiobook.currentPlaybackTime = audioEngine.currentTime
        try? modelContext.save()
    }

    /// Fires every 5 seconds; saves only during active playback to minimise writes.
    private func startPositionSaveTimer() {
        positionSaveTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, case .playing = self.playbackState else { return }
                self.savePlaybackPosition()
            }
    }

    /// Saves when the app moves to the background (home button, phone call screen, etc.).
    private func installBackgroundObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.savePlaybackPosition() }
            .store(in: &cancellables)
    }

    // MARK: - Private — Formatting

    /// "1:04:32" for ≥ 1 hour, "4:32" otherwise.
    static func formatTime(_ interval: TimeInterval) -> String {
        let total = Int(max(0, interval))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
}

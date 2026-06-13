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

    // MARK: - Playback Display Mode

    enum PlaybackDisplayMode {
        case entireBook
        case currentChapter
    }

    // MARK: - Sleep Timer

    enum SleepTimerOption: Equatable {
        case off
        case minutes(Int)
        case endOfChapter
    }

    // MARK: - Displayed State

    private(set) var playbackState: PlaybackState = .idle
    private(set) var playbackSpeed: Float = 1.0

    /// Elapsed time string, e.g. "1:04:32". Updated from engine every 0.5 s.
    private(set) var displayCurrentTime: String = "0:00"

    /// Remaining time string, e.g. "-2:11:05". Updated from engine every 0.5 s.
    private(set) var displayRemainingTime: String = "-0:00"

    /// Whether the slider and time labels are scoped to the whole book or the active chapter.
    private(set) var playbackDisplayMode: PlaybackDisplayMode = .entireBook

    // MARK: - Scrubbing

    /// Normalised position [0, 1] bound directly to the Slider.
    var scrubPosition: Double = 0

    /// True while the user is actively dragging the scrubber.
    private(set) var isScrubbing: Bool = false

    // MARK: - Displayed Audiobook

    private(set) var audiobook: Audiobook?

    /// Decoded cover image, cached at book-load time via CoverArtCache.
    private(set) var coverImage: UIImage?

    // MARK: - Chapters

    /// Controls the chapters sheet presented from PlayerView.
    var isChaptersPresented: Bool = false

    /// Chapters of the current audiobook sorted by play order. Cached at load time.
    private(set) var chapters: [Chapter] = []

    /// Index into `chapters` for the chapter that contains the current playback position.
    private(set) var currentChapterIndex: Int = 0

    /// Title shown in the player header.
    /// When the book is a single undivided file, the audiobook name is used.
    /// When the book has multiple chapters, the current chapter's title is shown.
    var playerTitle: String {
        guard chapters.count > 1 else {
            return audiobook?.title ?? ""
        }
        return chapters[currentChapterIndex].title
    }

    // MARK: - Bookmarks

    /// Controls the bookmarks sheet presented from PlayerView.
    var isBookmarksPresented: Bool = false

    /// Bookmarks for the current audiobook sorted by timestamp. Cached and invalidated on mutation.
    private(set) var bookmarks: [Bookmark] = []

    // MARK: - Sleep Timer

    private(set) var sleepTimerOption: SleepTimerOption = .off
    private(set) var sleepTimerRemaining: TimeInterval = 0

    @ObservationIgnored private var sleepTimerCancellable: AnyCancellable?

    // MARK: - Lull Analysis State

    private(set) var lullAnalysisState: LullAnalysisState = .idle

    @ObservationIgnored
    private let lullDetector = LullDetector()

    /// Raw current time exposed for lull-label computation.
    /// Not a stored property so it doesn't register as an @Observable dependency;
    /// label views re-render as a side-effect of scrubPosition ticks.
    var currentTime: TimeInterval { audioEngine.currentTime }

    /// The ID of the lull with the longest duration (most structurally significant).
    var longestLullID: UUID? {
        guard case .results(let lulls) = lullAnalysisState, !lulls.isEmpty else { return nil }
        return lulls.max(by: { $0.duration < $1.duration })?.id
    }

    /// Formatted label for a lull button: how far back it is from the current position.
    func lullLabel(for lull: LullResult) -> String {
        let delta = max(0, audioEngine.currentTime - lull.endTime)
        let secs = Int(delta)
        return String(format: "-%d:%02d", secs / 60, secs % 60)
    }

    /// Display label shown on the sleep timer button when the timer is active.
    var sleepTimerLabel: String {
        switch sleepTimerOption {
        case .off:
            return ""
        case .minutes:
            let total = Int(max(0, sleepTimerRemaining))
            return String(format: "%d:%02d", total / 60, total % 60)
        case .endOfChapter:
            return "Chapter"
        }
    }

    // MARK: - Speed Options

    static let availableSpeeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    var speedLabel: String {
        let f = playbackSpeed
        return f.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(f))×"
            : String(format: "%.2g×", f)
    }

    /// The current skip-forward interval as an integer, used to pick the matching SF Symbol.
    var skipForwardIntervalSeconds: Int { Int(settings.skipForwardInterval) }

    /// The current skip-backward interval as an integer, used to pick the matching SF Symbol.
    var skipBackwardIntervalSeconds: Int { Int(settings.skipBackwardInterval) }

    /// True whenever an audiobook is loaded into the engine (even while loading/paused).
    var isActive: Bool { audiobook != nil }

    var playPauseImage: String {
        if case .playing = playbackState { return "pause.fill" }
        return "play.fill"
    }

    // MARK: - Display Mode Toggle

    func togglePlaybackDisplayMode() {
        playbackDisplayMode = playbackDisplayMode == .entireBook ? .currentChapter : .entireBook
        guard !isScrubbing else { return }
        applyEngineTime(audioEngine.currentTime)
    }

    /// Summary label shown below the time row; acts as the toggle tap target.
    var displayProgressLabel: String {
        switch playbackDisplayMode {
        case .entireBook:
            let duration = audioEngine.duration
            guard duration > 0 else { return "0% completed" }
            let time = isScrubbing ? scrubPosition * duration : audioEngine.currentTime
            let pct = Int((time / duration * 100).rounded())
            return "\(pct)% completed"
        case .currentChapter:
            let chaps = chapters
            guard !chaps.isEmpty else { return "" }
            return "Chapter \(currentChapterIndex + 1) of \(chaps.count)"
        }
    }

    // MARK: - Computed display during scrub

    var scrubDisplayCurrentTime: String {
        guard isScrubbing else { return displayCurrentTime }
        switch playbackDisplayMode {
        case .entireBook:
            return Self.formatTime(scrubPosition * audioEngine.duration)
        case .currentChapter:
            let chaps = chapters
            guard !chaps.isEmpty else { return Self.formatTime(scrubPosition * audioEngine.duration) }
            return Self.formatTime(scrubPosition * chaps[currentChapterIndex].duration)
        }
    }

    var scrubDisplayRemainingTime: String {
        guard isScrubbing else { return displayRemainingTime }
        switch playbackDisplayMode {
        case .entireBook:
            let t = scrubPosition * audioEngine.duration
            return "-\(Self.formatTime(max(0, audioEngine.duration - t)))"
        case .currentChapter:
            let chaps = chapters
            guard !chaps.isEmpty else {
                let t = scrubPosition * audioEngine.duration
                return "-\(Self.formatTime(max(0, audioEngine.duration - t)))"
            }
            let chapterDuration = chaps[currentChapterIndex].duration
            return "-\(Self.formatTime(max(0, chapterDuration - scrubPosition * chapterDuration)))"
        }
    }

    // MARK: - Private

    private let audioEngine: any AudioEngineProtocol
    private let modelContext: ModelContext
    private let settings: AppSettings

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var positionSaveTimer: AnyCancellable?

    // MARK: - Init

    init(audioEngine: any AudioEngineProtocol, modelContext: ModelContext, appSettings: AppSettings) {
        self.audioEngine = audioEngine
        self.modelContext = modelContext
        self.settings = appSettings
        observeEngine()
        installBackgroundObserver()
        observeSkipIntervalSettings()
    }

    // MARK: - Lifecycle

    func loadAudiobook(_ audiobook: Audiobook, autoPlay: Bool = false) async {
        lullAnalysisState = .idle
        self.audiobook = audiobook
        self.chapters = audiobook.chapters.sorted { $0.orderIndex < $1.orderIndex }
        self.bookmarks = audiobook.bookmarks.sorted { $0.timestamp < $1.timestamp }
        self.coverImage = CoverArtCache.shared.image(for: audiobook)
        do {
            try await audioEngine.load(audiobook: audiobook)
            try? audioEngine.setPlaybackSpeed(settings.defaultSpeed)
            playbackSpeed = audioEngine.playbackSpeed
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
        Task { try? await audioEngine.skipForward(by: settings.skipForwardInterval) }
    }

    func skipBackward() {
        Task { try? await audioEngine.skipBackward(by: settings.skipBackwardInterval) }
    }

    func setSpeed(_ speed: Float) {
        try? audioEngine.setPlaybackSpeed(speed)
        playbackSpeed = audioEngine.playbackSpeed
    }

    func seekToChapter(_ chapter: Chapter) {
        isChaptersPresented = false
        Task { try? await audioEngine.seek(to: chapter.startTime) }
    }

    // MARK: - Lull Analysis

    func analyzeLulls() {
        guard case .idle = lullAnalysisState, audiobook != nil else { return }
        lullAnalysisState = .analyzing
        let to = audioEngine.currentTime
        let from = max(0, to - 300)  // last 5 minutes
        let chapters = audioEngine.resolvedChapters
        Task {
            let lulls = (try? await lullDetector.findLulls(in: chapters, from: from, to: to)) ?? []
            lullAnalysisState = .results(lulls)
        }
    }

    func seekToLull(_ lull: LullResult) {
        Task { try? await audioEngine.seek(to: max(0, lull.endTime - 0.5)) }
    }

    // MARK: - Bookmarks

    func addBookmark() {
        guard let audiobook else { return }
        let title = Self.formatTime(audioEngine.currentTime)
        let bookmark = Bookmark(title: title, timestamp: audioEngine.currentTime, audiobook: audiobook)
        audiobook.bookmarks.append(bookmark)
        bookmarks = audiobook.bookmarks.sorted { $0.timestamp < $1.timestamp }
        try? modelContext.save()
    }

    func deleteBookmark(_ bookmark: Bookmark) {
        audiobook?.bookmarks.removeAll { $0.id == bookmark.id }
        modelContext.delete(bookmark)
        bookmarks = audiobook?.bookmarks.sorted { $0.timestamp < $1.timestamp } ?? []
        try? modelContext.save()
    }

    func seekToBookmark(_ bookmark: Bookmark) {
        isBookmarksPresented = false
        Task { try? await audioEngine.seek(to: bookmark.timestamp) }
    }

    // MARK: - Sleep Timer

    func setSleepTimer(_ option: SleepTimerOption) {
        sleepTimerCancellable?.cancel()
        sleepTimerCancellable = nil
        sleepTimerOption = option
        sleepTimerRemaining = 0

        guard case .minutes(let n) = option else { return }

        sleepTimerRemaining = TimeInterval(n * 60)
        sleepTimerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.sleepTimerRemaining > 1 {
                    self.sleepTimerRemaining -= 1
                } else {
                    self.sleepTimerRemaining = 0
                    self.audioEngine.pause()
                    self.savePlaybackPosition()
                    self.sleepTimerOption = .off
                    self.sleepTimerCancellable?.cancel()
                    self.sleepTimerCancellable = nil
                }
            }
    }

    // MARK: - Scrubbing

    func beginScrubbing() {
        isScrubbing = true
    }

    func commitScrub() async {
        let targetTime: TimeInterval
        switch playbackDisplayMode {
        case .entireBook:
            targetTime = scrubPosition * audioEngine.duration
        case .currentChapter:
            let chaps = chapters
            if chaps.isEmpty {
                targetTime = scrubPosition * audioEngine.duration
            } else {
                let chapter = chaps[currentChapterIndex]
                targetTime = chapter.startTime + scrubPosition * chapter.duration
            }
        }
        isScrubbing = false
        try? await audioEngine.seek(to: targetTime)
    }

    // MARK: - Private — Engine Observation

    private func observeEngine() {
        audioEngine.currentTimePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                guard let self, !self.isScrubbing else { return }
                let prevChapterIndex = self.currentChapterIndex
                self.applyEngineTime(time)
                // Sleep-timer: endOfChapter — pause as soon as the chapter advances.
                if self.sleepTimerOption == .endOfChapter
                    && self.currentChapterIndex > prevChapterIndex {
                    self.audioEngine.pause()
                    self.savePlaybackPosition()
                    self.sleepTimerOption = .off
                }
            }
            .store(in: &cancellables)

        audioEngine.playbackStatePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] state in
                guard let self else { return }
                self.playbackState = state
                self.playbackSpeed = self.audioEngine.playbackSpeed

                switch state {
                case .playing:
                    self.startPositionSaveTimer()
                case .paused, .finished:
                    self.stopPositionSaveTimer()
                    self.savePlaybackPosition()
                default:
                    self.stopPositionSaveTimer()
                }
            }
            .store(in: &cancellables)
    }

    private func applyEngineTime(_ time: TimeInterval) {
        let duration = audioEngine.duration
        let newIndex = resolveChapterIndex(for: time)
        if newIndex != currentChapterIndex { currentChapterIndex = newIndex }

        let newScrub: Double
        let newCurrent: String
        let newRemaining: String

        switch playbackDisplayMode {
        case .entireBook:
            newScrub    = duration > 0 ? min(1, time / duration) : 0
            newCurrent  = Self.formatTime(time)
            newRemaining = "-\(Self.formatTime(max(0, duration - time)))"

        case .currentChapter:
            if chapters.isEmpty {
                newScrub    = duration > 0 ? min(1, time / duration) : 0
                newCurrent  = Self.formatTime(time)
                newRemaining = "-\(Self.formatTime(max(0, duration - time)))"
            } else {
                let chapter = chapters[newIndex]
                let elapsed = max(0, time - chapter.startTime)
                let dur     = chapter.duration
                newScrub    = dur > 0 ? min(1, elapsed / dur) : 0
                newCurrent  = Self.formatTime(elapsed)
                newRemaining = "-\(Self.formatTime(max(0, dur - elapsed)))"
            }
        }

        // scrubPosition drives the slider and must update every tick for smooth motion.
        // The string labels only change once per second — skip the write when unchanged
        // to avoid invalidating views that only read those labels.
        scrubPosition = newScrub
        if displayCurrentTime  != newCurrent   { displayCurrentTime  = newCurrent }
        if displayRemainingTime != newRemaining { displayRemainingTime = newRemaining }
    }

    private func resolveChapterIndex(for time: TimeInterval) -> Int {
        guard !chapters.isEmpty else { return 0 }
        var low = 0, high = chapters.count - 1
        while low <= high {
            let mid = (low + high) / 2
            let chapter = chapters[mid]
            if time >= chapter.startTime && time < chapter.startTime + chapter.duration {
                return mid
            } else if time < chapter.startTime {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        return max(0, chapters.count - 1)
    }

    // MARK: - Private — Persistence

    private func savePlaybackPosition() {
        guard let audiobook else { return }
        audiobook.currentPlaybackTime = audioEngine.currentTime
        try? modelContext.save()
    }

    private func startPositionSaveTimer() {
        guard positionSaveTimer == nil else { return }
        positionSaveTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.savePlaybackPosition() }
    }

    private func stopPositionSaveTimer() {
        positionSaveTimer?.cancel()
        positionSaveTimer = nil
    }

    private func installBackgroundObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.savePlaybackPosition() }
            .store(in: &cancellables)
    }

    private func observeSkipIntervalSettings() {
        pushSkipIntervalsToEngine()
        withObservationTracking {
            _ = settings.skipForwardInterval
            _ = settings.skipBackwardInterval
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.pushSkipIntervalsToEngine()
                self?.observeSkipIntervalSettings()
            }
        }
    }

    private func pushSkipIntervalsToEngine() {
        audioEngine.updateRemoteSkipIntervals(
            forward: settings.skipForwardInterval,
            backward: settings.skipBackwardInterval
        )
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

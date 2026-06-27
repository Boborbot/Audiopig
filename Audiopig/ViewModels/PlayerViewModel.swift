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
    private(set) var activeEQPresetID: String = SpeechEQPreset.off.id
    private(set) var voiceBoostLevel: VoiceBoostLevel = .off

    /// Elapsed time string, e.g. "1:04:32". Updated from engine every 0.5 s.
    private(set) var displayCurrentTime: String = "0:00"

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

    /// Controls the playback speed sheet presented from PlayerView.
    var isSpeedSheetPresented: Bool = false

    /// Controls the EQ and Voice Boost sheet presented from PlayerView.
    var isEQSheetPresented: Bool = false

    /// Controls the Plus paywall sheet when lull detection is tapped without access.
    var isPaywallPresented: Bool = false

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

    /// Set to the bookmark being edited to present BookmarkEditView from BookmarksListView.
    var editingBookmark: Bookmark? = nil

    /// Set when a new bookmark is created via the player button tap, driving the quick-edit
    /// sheet directly from PlayerView (separate from the list-edit flow).
    var pendingNewBookmark: Bookmark? = nil

    // MARK: - Subtitles

    enum SubtitlePresentation: Equatable {
        case hidden
        case unavailable
        case needsGeneration
        case loading(String)
        case ready
        case partial(String)
        case failed(String)
    }

    struct SubtitleLineItem: Identifiable, Equatable {
        var id: String { "\(orderIndex)-\(startTime)" }
        let orderIndex: Int
        let text: String
        let startTime: TimeInterval
        let isActive: Bool
    }

    struct SubtitleSearchResultItem: Identifiable, Equatable {
        var id: String { "\(orderIndex)-\(startTime)" }
        let orderIndex: Int
        let text: String
        let startTime: TimeInterval
        let chapterTitle: String?
    }

    struct SubtitleSearchResults: Equatable {
        let items: [SubtitleSearchResultItem]
        let totalCount: Int
    }

    /// Whether the subtitles panel is shown in the player.
    var isSubtitlesVisible: Bool = false

    private(set) var subtitlePresentation: SubtitlePresentation = .hidden
    private(set) var subtitleLines: [SubtitleLineItem] = []
    /// Controls the subtitles management sheet (long-press on the captions button).
    var isSubtitlesPresented: Bool = false
    /// Controls the subtitle search sheet (search pill on the player).
    var isSubtitleSearchPresented: Bool = false

    enum WholeBookSubtitleJobState: Equatable {
        case idle
        case preparing
        case running(completed: Int, total: Int, message: String)
        case paused(completed: Int, total: Int)
        case failed(String)

        var isActive: Bool {
            switch self {
            case .idle, .failed: return false
            case .preparing, .running, .paused: return true
            }
        }
    }

    private(set) var wholeBookJobState: WholeBookSubtitleJobState = .idle

    /// Which Plus feature triggered the paywall sheet.
    private(set) var paywallFeature: PaywallViewModel.Feature = .paragraphBreaks

    @ObservationIgnored
    private var subtitleCues: [SubtitleCueTiming] = []

    @ObservationIgnored
    private var subtitleSegments: [SubtitleTranscriptionSegmentTiming] = []

    /// Observable cue count so subtitle sheets refresh when cues are added or removed.
    private(set) var savedSubtitleCueCount: Int = 0

    /// Observable segment count so coverage metrics refresh after transcription jobs.
    private(set) var savedSubtitleSegmentCount: Int = 0

    @ObservationIgnored
    private var subtitleGenerationTask: Task<Void, Never>?

    @ObservationIgnored
    private var activeGenerationScope: SubtitleGenerationScope?

    @ObservationIgnored
    private var subtitleProgressMessage: String?

    @ObservationIgnored
    private var subtitleOrchestrator: SubtitleGenerationOrchestrator?

    /// Bumped when a near-playhead job is cancelled or superseded so stale task handlers no-op.
    @ObservationIgnored
    private var subtitleGenerationEpoch: UInt64 = 0

    @ObservationIgnored
    private var autoTranscribeBlockedUntilPlayhead: TimeInterval = -.infinity

    @ObservationIgnored
    private var lastAppliedEngineTime: TimeInterval?

    @ObservationIgnored
    private var isAppInForeground = true

    var subtitleCoverageSummary: SubtitleCoverageSummary {
        _ = savedSubtitleCueCount
        _ = savedSubtitleSegmentCount
        guard let audiobook else {
            return SubtitleCoverageSummary(
                cueCount: 0,
                bookDuration: 0,
                coveredWindowCount: 0,
                totalWindowCount: 0,
                uncoveredWindowCount: 0,
                transcribedDurationFraction: 0,
                estimatedStorageBytes: 0
            )
        }
        return SubtitleCoverageCalculator.summary(
            cues: subtitleCues,
            segments: subtitleSegments,
            bookDuration: audiobook.duration
        )
    }

    var hasUncoveredSubtitleWindows: Bool {
        _ = savedSubtitleSegmentCount
        guard let audiobook else { return false }
        return !SubtitleSegmentPlanner.uncoveredWindows(
            bookDuration: audiobook.duration,
            segments: subtitleSegments
        ).isEmpty
    }

    var hasSavedSubtitles: Bool { savedSubtitleCueCount > 0 }

    /// True while any subtitle transcription job is running (near-playhead or whole-book).
    var isSubtitleTranscriptionActive: Bool {
        activeGenerationScope != nil || wholeBookJobState.isActive
    }

    /// Per-book preference: auto-generate the next section as the listener approaches saved coverage.
    var transcribeAsYouGoEnabled: Bool {
        get { audiobook?.subtitlesTranscribeAsYouGo ?? false }
        set {
            guard let audiobook else { return }
            audiobook.subtitlesTranscribeAsYouGo = newValue
            try? modelContext.save()
        }
    }

    // MARK: - Sleep Timer

    private(set) var sleepTimerOption: SleepTimerOption = .off
    private(set) var sleepTimerRemaining: TimeInterval = 0

    @ObservationIgnored private var sleepTimerCancellable: AnyCancellable?

    // MARK: - Lull Analysis State

    private(set) var lullAnalysisState: LullAnalysisState = .idle

    @ObservationIgnored
    private var smartRewindSessionOffsets: SmartRewindWindowOffsets?

    @ObservationIgnored
    private let lullDetector = LullDetector()

    /// Raw current time exposed for lull-label computation.
    /// Not a stored property so it doesn't register as an @Observable dependency;
    /// label views re-render as a side-effect of scrubPosition ticks.
    var currentTime: TimeInterval { audioEngine.currentTime }

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

    static let minPlaybackSpeed: Float = 0.25
    static let maxPlaybackSpeed: Float = 4.0
    static let playbackSpeedStep: Float = 0.05
    /// Default preset buttons (customizable in Settings).
    static let defaultSpeedPresets: [Float] = [1.0, 1.2, 1.5]

    var speedLabel: String {
        Self.formatSpeedLabel(playbackSpeed)
    }

    var speedPresets: [Float] {
        settings.speedPresets.isEmpty ? Self.defaultSpeedPresets : settings.speedPresets
    }

    var speechEQPresets: [SpeechEQPreset] {
        SpeechEQPreset.all
    }

    var activeSpeechEQPreset: SpeechEQPreset {
        SpeechEQPreset.validated(activeEQPresetID)
    }

    var isAudioEnhancementActive: Bool {
        activeEQPresetID != SpeechEQPreset.off.id || voiceBoostLevel.isEnabled
    }

    static func formatSpeedLabel(_ speed: Float) -> String {
        WatchSpeedRange.formatLabel(speed)
    }

    static func normalizedSpeed(_ speed: Float) -> Float {
        WatchSpeedRange.normalized(speed)
    }

    func isSpeedPresetActive(_ preset: Float) -> Bool {
        abs(playbackSpeed - preset) < Self.playbackSpeedStep / 2
    }

    /// The current skip-forward interval as an integer, used to pick the matching SF Symbol.
    var skipForwardIntervalSeconds: Int { Int(settings.skipForwardInterval) }

    /// The current skip-backward interval as an integer, used to pick the matching SF Symbol.
    var skipBackwardIntervalSeconds: Int { Int(settings.skipBackwardInterval) }

    /// Typeface for on-screen subtitles in the player overlay.
    var subtitleFont: SubtitleFont { settings.subtitleFont }

    /// True whenever an audiobook is loaded into the engine (even while loading/paused).
    var isActive: Bool { audiobook != nil }

    var playPauseImage: String {
        if case .playing = playbackState { return "pause.fill" }
        return "play.fill"
    }

    // MARK: - Display Mode Toggle

    /// True when the left timestamp shows speed-adjusted remaining time instead of elapsed.
    var showsRemainingOnLeft: Bool { settings.leftTimeShowsRemaining }

    func toggleLeftTimeDisplay() {
        settings.leftTimeShowsRemaining.toggle()
    }

    func togglePlaybackDisplayMode() {
        playbackDisplayMode = playbackDisplayMode == .entireBook ? .currentChapter : .entireBook
        let newScope: PlaybackTimelineScope = (playbackDisplayMode == .entireBook)
            ? .entireBook
            : .currentChapter
        settings.playbackTimelineScope = newScope
        audioEngine.setNowPlayingTimelineScope(newScope.nowPlayingScope)
        watchBridge?.publishSettings(
            settings.watchSettingsSnapshot(
                hasParagraphBreaksAccess: monetization.hasAccess(to: .paragraphBreaks),
                hasWatchArtworkViewAccess: monetization.hasAccess(to: .watchArtworkView)
            )
        )
        guard !isScrubbing else { return }
        applyEngineTime(audioEngine.currentTime)
        publishWatchSnapshot(immediate: true, includeArtwork: false)
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

    /// Left timestamp: elapsed by default; tap toggles to speed-adjusted remaining.
    var scrubDisplayLeftTime: String {
        if showsRemainingOnLeft {
            return formatSpeedAdjustedRemaining(contentRemainingInterval())
        }
        return scrubDisplayCurrentTime
    }

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

    /// Right timestamp: content remaining divided by playback speed (wall-clock time left).
    var scrubDisplayRemainingTime: String {
        formatSpeedAdjustedRemaining(contentRemainingInterval())
    }

    // MARK: - Private

    /// Called once when playback naturally reaches the end of the loaded book.
    @ObservationIgnored
    var onNaturalFinish: ((Audiobook) -> Void)?
    var onPlaybackPositionSaved: ((_ isPeriodicSave: Bool) -> Void)?
    var onAudiobookLoaded: (() -> Void)?

    @ObservationIgnored
    private var didReportNaturalFinish = false

    private let audioEngine: any AudioEngineProtocol
    private let modelContext: ModelContext
    private let settings: AppSettings
    private let watchBridge: (any WatchConnectivityBridgeProtocol)?
    private let monetization: any MonetizationServiceProtocol
    private let subtitleStore: any SubtitleStoreProtocol
    private let subtitleTranscriptionService: any SubtitleTranscriptionServiceProtocol

    @ObservationIgnored
    private var watchRevision: UInt64 = 0

    @ObservationIgnored
    private var lastWatchPublishTime: Date = .distantPast

    @ObservationIgnored
    private var lastPublishedBookID: UUID?

    @ObservationIgnored
    private var cancellables = Set<AnyCancellable>()

    @ObservationIgnored
    private var positionSaveTimer: AnyCancellable?

    /// Last engine timeline position used to compute listening deltas.
    @ObservationIgnored
    private var lastListenedPositionSample: TimeInterval?

    /// Matches `AudioEngine`'s periodic time observer interval (0.5 s).
    private static let listeningSampleInterval: TimeInterval = 0.5

    // MARK: - Init

    init(
        audioEngine: any AudioEngineProtocol,
        modelContext: ModelContext,
        appSettings: AppSettings,
        watchBridge: (any WatchConnectivityBridgeProtocol)? = nil,
        monetization: any MonetizationServiceProtocol,
        subtitleStore: any SubtitleStoreProtocol,
        subtitleTranscriptionService: any SubtitleTranscriptionServiceProtocol = SubtitleTranscriptionService()
    ) {
        self.audioEngine = audioEngine
        self.modelContext = modelContext
        self.settings = appSettings
        self.watchBridge = watchBridge
        self.monetization = monetization
        self.subtitleStore = subtitleStore
        self.subtitleTranscriptionService = subtitleTranscriptionService
        self.playbackDisplayMode = PlaybackDisplayMode(scope: appSettings.playbackTimelineScope)
        self.audioEngine.setNowPlayingTimelineScope(appSettings.playbackTimelineScope.nowPlayingScope)
        observeEngine()
        installBackgroundObserver()
        observeSkipIntervalSettings()
        restoreSleepTimer()
    }

    // MARK: - Lifecycle

    func loadAudiobook(_ audiobook: Audiobook, autoPlay: Bool = false) async {
        if audioEngine.loadedAudiobookID == audiobook.id {
            switch audioEngine.playbackState {
            case .playing, .paused, .finished, .idle:
                resumeLoadedAudiobook(audiobook, autoPlay: autoPlay)
                return
            case .loading, .failed:
                break
            }
        }

        lullAnalysisState = .idle
        smartRewindSessionOffsets = nil
        cancelSubtitleGeneration()
        wholeBookJobState = .idle
        autoTranscribeBlockedUntilPlayhead = -.infinity
        lastAppliedEngineTime = nil
        isSubtitlesVisible = false
        subtitlePresentation = .hidden
        subtitleLines = []
        subtitleCues = []
        subtitleSegments = []
        savedSubtitleCueCount = 0
        savedSubtitleSegmentCount = 0
        didReportNaturalFinish = false
        resetListeningSample()
        self.audiobook = audiobook
        self.chapters = audiobook.chapters.sorted { $0.orderIndex < $1.orderIndex }
        self.bookmarks = audiobook.bookmarks.sorted { $0.timestamp < $1.timestamp }
        reloadSubtitleData(for: audiobook)
        self.coverImage = CoverArtCache.shared.image(for: audiobook)
        audiobook.lastPlayedAt = .now
        try? modelContext.save()
        do {
            try await audioEngine.load(audiobook: audiobook)
            audioEngine.setNowPlayingTimelineScope(settings.playbackTimelineScope.nowPlayingScope)
            let desiredSpeed = playbackSpeedForLoad(of: audiobook)

            try? audioEngine.setPlaybackSpeed(desiredSpeed)
            playbackSpeed = audioEngine.playbackSpeed
            applyAudioEnhancement(enhancementForLoad(of: audiobook))
            if autoPlay { try? audioEngine.play() }
        } catch {
            playbackState = .failed(message: "Could not load \"\(audiobook.title)\".")
        }
        WidgetSnapshotWriter.updateLastPlayed(
            title: audiobook.title,
            author: audiobook.author,
            audiobookID: audiobook.id,
            progress: widgetProgress(for: audiobook),
            coverImage: self.coverImage
        )
        publishWatchSnapshot(immediate: true, includeArtwork: true)
        publishWatchChaptersIfNeeded()
        onAudiobookLoaded?()
    }

    /// Re-selects a book that is already loaded without tearing down playback.
    private func resumeLoadedAudiobook(_ audiobook: Audiobook, autoPlay: Bool) {
        self.audiobook = audiobook
        self.chapters = audiobook.chapters.sorted { $0.orderIndex < $1.orderIndex }
        self.bookmarks = audiobook.bookmarks.sorted { $0.timestamp < $1.timestamp }
        reloadSubtitleData(for: audiobook)
        self.coverImage = CoverArtCache.shared.image(for: audiobook)
        audiobook.lastPlayedAt = .now
        try? modelContext.save()

        if autoPlay, audioEngine.playbackState != .playing {
            try? audioEngine.play()
        }

        WidgetSnapshotWriter.updateLastPlayed(
            title: audiobook.title,
            author: audiobook.author,
            audiobookID: audiobook.id,
            progress: widgetProgress(for: audiobook),
            coverImage: self.coverImage
        )
        publishWatchSnapshot(immediate: true, includeArtwork: false)
        publishWatchChaptersIfNeeded()
        onAudiobookLoaded?()
    }

    // MARK: - Transport

    func togglePlayPause() {
        switch playbackState {
        case .playing:
            pause()
        case .paused, .finished, .idle:
            play()
        case .loading, .failed:
            break
        }
    }

    func play() {
        try? audioEngine.play()
        publishWatchSnapshot(immediate: true, includeArtwork: false)
    }

    func pause() {
        audioEngine.pause()
        publishWatchSnapshot(immediate: true, includeArtwork: false)
    }

    func syncWatchState(immediate: Bool = true, includeArtwork: Bool = false) {
        publishWatchSnapshot(immediate: immediate, includeArtwork: includeArtwork)
        publishWatchChaptersIfNeeded()
    }

    private func publishWatchChaptersIfNeeded() {
        guard let audiobook, let watchBridge else { return }
        watchBridge.publishChapters(
            WatchSnapshotBuilder.makeChaptersPayload(bookID: audiobook.id, chapters: chapters)
        )
    }

    func skipForward() {
        endScrubbingForTransport()
        resetListeningSample()
        Task {
            try? await audioEngine.skipForward(by: settings.skipForwardInterval)
            syncDisplayFromEngine()
            publishWatchSnapshot(immediate: true, includeArtwork: false)
        }
    }

    func skipBackward() {
        endScrubbingForTransport()
        resetListeningSample()
        Task {
            try? await audioEngine.skipBackward(by: settings.skipBackwardInterval)
            syncDisplayFromEngine()
            publishWatchSnapshot(immediate: true, includeArtwork: false)
        }
    }

    func setSpeed(_ speed: Float) {
        let normalized = Self.normalizedSpeed(speed)
        try? audioEngine.setPlaybackSpeed(normalized)
        playbackSpeed = audioEngine.playbackSpeed
        if settings.universalPlaybackSpeedEnabled {
            settings.universalPlaybackSpeed = playbackSpeed
        } else if let audiobook {
            audiobook.lastPlaybackSpeed = playbackSpeed
            try? modelContext.save()
        }
        publishWatchSnapshot(immediate: true, includeArtwork: false)
    }

    func setEQPreset(_ presetID: String) {
        let preset = SpeechEQPreset.validated(presetID)
        if preset.id != SpeechEQPreset.off.id, !monetization.hasAccess(to: .eq) {
            presentEQPaywall()
            return
        }
        try? audioEngine.setEQPreset(preset.id)
        activeEQPresetID = audioEngine.activeEQPresetID
        if let audiobook {
            if preset.id == SpeechEQPreset.off.id {
                audiobook.lastEQEnabled = false
            } else {
                audiobook.lastEQPresetID = preset.id
                audiobook.lastEQEnabled = true
            }
            try? modelContext.save()
        }
    }

    var rememberedEQPresetID: String {
        if let id = audiobook?.lastEQPresetID, id != SpeechEQPreset.off.id {
            return SpeechEQPreset.validated(id).id
        }
        return settings.rememberedDefaultEQPresetID
    }

    func setRememberedEQPresetID(_ presetID: String) {
        let validated = SpeechEQPreset.validated(presetID).id
        guard validated != SpeechEQPreset.off.id else { return }
        if let audiobook {
            audiobook.lastEQPresetID = validated
            try? modelContext.save()
        }
    }

    func setVoiceBoostLevel(_ level: VoiceBoostLevel) {
        try? audioEngine.setVoiceBoostLevel(level)
        voiceBoostLevel = audioEngine.voiceBoostLevel
        if let audiobook {
            audiobook.lastVoiceBoostLevel = level.rawValue
            audiobook.lastVoiceBoostEnabled = nil
            try? modelContext.save()
        }
    }

    private func perBookEQPresetID(for audiobook: Audiobook) -> String? {
        migrateLegacyEQStateIfNeeded(for: audiobook)
        if audiobook.lastEQEnabled == false {
            return SpeechEQPreset.off.id
        }
        if let id = audiobook.lastEQPresetID, id != SpeechEQPreset.off.id {
            return SpeechEQPreset.validated(id).id
        }
        return nil
    }

    private func migrateLegacyEQStateIfNeeded(for audiobook: Audiobook) {
        guard audiobook.lastEQEnabled == nil else { return }
        guard let id = audiobook.lastEQPresetID else { return }

        if id == SpeechEQPreset.off.id {
            audiobook.lastEQEnabled = false
            audiobook.lastEQPresetID = nil
        } else {
            audiobook.lastEQEnabled = true
        }
        try? modelContext.save()
    }

    private func perBookVoiceBoostLevel(for audiobook: Audiobook) -> VoiceBoostLevel? {
        if let raw = audiobook.lastVoiceBoostLevel {
            return VoiceBoostLevel.validated(raw)
        }
        if let legacyEnabled = audiobook.lastVoiceBoostEnabled {
            let level = VoiceBoostLevel.migrated(fromLegacyEnabled: legacyEnabled)
            audiobook.lastVoiceBoostLevel = level.rawValue
            audiobook.lastVoiceBoostEnabled = nil
            try? modelContext.save()
            return level
        }
        return nil
    }

    func presentEQSheet() {
        isEQSheetPresented = true
    }

    var hasEQAccess: Bool {
        monetization.hasAccess(to: .eq)
    }

    func refreshAudioEnhancementFromSettings() {
        guard let audiobook else { return }
        applyAudioEnhancement(enhancementForLoad(of: audiobook))
    }

    private func applyAudioEnhancement(_ enhancement: AudioEnhancementSettings) {
        try? audioEngine.setEQPreset(enhancement.eqPresetID)
        try? audioEngine.setVoiceBoostLevel(enhancement.voiceBoostLevel)
        activeEQPresetID = audioEngine.activeEQPresetID
        voiceBoostLevel = audioEngine.voiceBoostLevel
    }

    private func enhancementForLoad(of audiobook: Audiobook) -> AudioEnhancementSettings {
        let resolved = AudioEnhancementResolver.resolve(
            universalEnabled: false,
            universalEQPresetID: settings.universalEQPresetID,
            universalVoiceBoostLevel: settings.universalVoiceBoostLevel,
            perBookEQPresetID: perBookEQPresetID(for: audiobook),
            perBookVoiceBoostLevel: perBookVoiceBoostLevel(for: audiobook),
            defaultEQPresetID: settings.defaultEQPresetID,
            defaultVoiceBoostLevel: settings.defaultVoiceBoostLevel
        )
        guard monetization.hasAccess(to: .eq) else {
            return AudioEnhancementSettings(
                eqPresetID: SpeechEQPreset.off.id,
                voiceBoostLevel: resolved.voiceBoostLevel
            )
        }
        return resolved
    }

    func adjustSpeed(by delta: Float) {
        let stepCount = Int((delta / Self.playbackSpeedStep).rounded())
        guard stepCount != 0 else { return }
        setSpeed(WatchSpeedRange.adjusted(playbackSpeed, byStepCount: stepCount))
    }

    func seekToChapter(_ chapter: Chapter) {
        isChaptersPresented = false
        endScrubbingForTransport()
        resetListeningSample()
        Task {
            try? await audioEngine.seek(to: chapter.startTime)
            syncDisplayFromEngine()
            publishWatchSnapshot(immediate: true, includeArtwork: false)
        }
    }

    // MARK: - Chapter Editing

    struct ChapterEditDraft: Identifiable, Equatable {
        let id: UUID
        var title: String
    }

    func makeChapterEditDrafts() -> [ChapterEditDraft] {
        chapters.map { ChapterEditDraft(id: $0.id, title: $0.title) }
    }

    func saveChapterEdits(_ drafts: [ChapterEditDraft]) {
        guard let audiobook, !drafts.isEmpty else { return }

        let existingByID = Dictionary(uniqueKeysWithValues: chapters.map { ($0.id, $0) })
        let orderedChapters: [Chapter] = drafts.compactMap { existingByID[$0.id] }
        guard orderedChapters.count == drafts.count else { return }

        let draftIDs = Set(drafts.map(\.id))
        for chapter in chapters where !draftIDs.contains(chapter.id) {
            audiobook.chapters.removeAll { $0.id == chapter.id }
            modelContext.delete(chapter)
        }

        let usesStackedTimeline = ChapterTimelineEditor.usesStackedTimeline(
            fileURLs: orderedChapters.map(\.fileURL)
        )
        let stackedStartTimes = usesStackedTimeline
            ? ChapterTimelineEditor.stackedStartTimes(durations: orderedChapters.map(\.duration))
            : []

        for (index, draft) in drafts.enumerated() {
            let chapter = orderedChapters[index]
            chapter.title = ChapterTimelineEditor.sanitizedTitle(
                draft.title,
                fallback: "Chapter \(index + 1)"
            )
            chapter.orderIndex = index
            if usesStackedTimeline {
                chapter.startTime = stackedStartTimes[index]
            }
        }

        if usesStackedTimeline {
            audiobook.duration = ChapterTimelineEditor.totalDuration(
                durations: orderedChapters.map(\.duration)
            )
        }

        if let primaryChapterURL = orderedChapters.first?.fileURL {
            audiobook.fileURL = primaryChapterURL
        }

        if audiobook.currentPlaybackTime > audiobook.duration {
            audiobook.currentPlaybackTime = audiobook.duration
        }

        try? modelContext.save()
        self.chapters = audiobook.chapters.sorted { $0.orderIndex < $1.orderIndex }

        if audioEngine.loadedAudiobookID == audiobook.id {
            audioEngine.updateResolvedChapters(from: audiobook)
            applyEngineTime(audioEngine.currentTime)
        }

        publishWatchChaptersIfNeeded()
        publishWatchSnapshot(immediate: true, includeArtwork: false)
    }

    // MARK: - Subtitles

    var subtitlesSupported: Bool {
        subtitleTranscriptionService.isSupported
    }

    func toggleSubtitles() {
        guard audiobook != nil else { return }
        if isSubtitlesVisible {
            isSubtitlesVisible = false
            subtitlePresentation = .hidden
            if activeGenerationScope == .nearPlayhead {
                cancelSubtitleGeneration()
            }
            return
        }

        guard monetization.hasAccess(to: .subtitles) else {
            presentSubtitlesPaywall()
            return
        }

        isSubtitlesVisible = true
        refreshSubtitlePresentation()
        updateSubtitleDisplay(at: audioEngine.currentTime)
    }

    /// Closes the subtitles overlay without starting generation.
    func dismissSubtitlesWithoutGenerating() {
        isSubtitlesVisible = false
        subtitlePresentation = .hidden
        subtitleLines = []
        if activeGenerationScope == .nearPlayhead {
            cancelSubtitleGeneration()
            audiobook?.subtitleGenerationStatus = subtitleCues.isEmpty ? .notGenerated : .partial
            try? modelContext.save()
        }
    }

    /// Updates subtitle preview while the user drags the scrubber.
    func previewSubtitlesAtScrubPosition() {
        guard isScrubbing, isSubtitlesVisible else { return }
        let time = scrubTargetTime(for: scrubPosition)
        updateSubtitleDisplay(at: time)
        refreshSubtitlePresentation(at: time)
    }

    func generateSubtitlesNearPlayhead() {
        startSubtitleGeneration(scope: .nearPlayhead)
    }

    func generateSubtitlesWholeBook() {
        startSubtitleGeneration(scope: .wholeBook)
    }

    func pauseWholeBookTranscription() {
        guard activeGenerationScope == .wholeBook else { return }
        Task { await subtitleOrchestrator?.pause() }
        if case .running(let completed, let total, _) = wholeBookJobState {
            wholeBookJobState = .paused(completed: completed, total: total)
        }
    }

    func resumeWholeBookTranscription() {
        guard activeGenerationScope == .wholeBook else { return }
        Task { await subtitleOrchestrator?.resume() }
        if case .paused(let completed, let total) = wholeBookJobState {
            wholeBookJobState = .running(
                completed: completed,
                total: total,
                message: "Transcribing entire book…"
            )
        }
    }

    func cancelWholeBookTranscription() {
        guard activeGenerationScope == .wholeBook else { return }
        subtitleGenerationTask?.cancel()
        Task { await subtitleOrchestrator?.cancel() }
        subtitleGenerationTask = nil
        subtitleOrchestrator = nil
        activeGenerationScope = nil
        wholeBookJobState = .idle
        if let audiobook {
            audiobook.subtitleGenerationStatus = subtitleCues.isEmpty ? .notGenerated : .partial
            try? modelContext.save()
        }
        refreshSubtitlePresentation()
    }

    func exportSubtitles(format: SubtitleExportFormat) throws -> URL? {
        guard let audiobook else { return nil }
        return try SubtitleExportService.export(
            audiobook: audiobook,
            cues: subtitleCues,
            format: format
        )
    }

    /// Removes all saved subtitle cues for the current book and resets generation state.
    func deleteSavedTranscription() {
        guard let audiobook else { return }

        if activeGenerationScope == .wholeBook {
            cancelWholeBookTranscription()
        } else {
            cancelSubtitleGeneration()
        }

        try? subtitleStore.deleteAllCues(for: audiobook)
        try? subtitleStore.deleteAllSegments(for: audiobook)
        subtitleCues = []
        subtitleSegments = []
        subtitleLines = []
        savedSubtitleCueCount = 0
        savedSubtitleSegmentCount = 0
        audiobook.subtitleGenerationStatus = .notGenerated
        audiobook.subtitleLastCoveredEndTime = 0
        audiobook.subtitleGenerationScope = nil
        try? modelContext.save()
        refreshSubtitlePresentation()
        updateSubtitleDisplay(at: audioEngine.currentTime)
    }

    func seekToSubtitle(at startTime: TimeInterval) {
        endScrubbingForTransport()
        resetListeningSample()
        Task {
            try? await audioEngine.seek(to: startTime)
            syncDisplayFromEngine()
            publishWatchSnapshot(immediate: true, includeArtwork: false)
        }
    }

    func seekToSubtitleFromSearch(at startTime: TimeInterval) {
        isSubtitleSearchPresented = false
        seekToSubtitle(at: startTime)
    }

    func subtitleSearchResults(matching query: String) -> SubtitleSearchResults {
        let search = SubtitleSearch.search(query: query, in: subtitleCues)
        let items = search.matches.map { cue in
            SubtitleSearchResultItem(
                orderIndex: cue.orderIndex,
                text: cue.text,
                startTime: cue.startTime,
                chapterTitle: chapterTitle(at: cue.startTime)
            )
        }
        return SubtitleSearchResults(items: items, totalCount: search.totalCount)
    }

    private func chapterTitle(at time: TimeInterval) -> String? {
        let summaries = chapters.map {
            WatchChapterSummary(
                id: $0.id,
                title: $0.title,
                startTime: $0.startTime,
                duration: $0.duration,
                orderIndex: $0.orderIndex
            )
        }
        return ChapterProgressCalculator.chapterTitle(at: time, chapters: summaries)
    }

    func retrySubtitleGeneration() {
        generateSubtitlesNearPlayhead()
    }

    func makePaywallViewModel() -> PaywallViewModel {
        PaywallViewModel(monetization: monetization, feature: paywallFeature)
    }

    private func reloadSubtitleData(for audiobook: Audiobook) {
        let loaded = (try? subtitleStore.sortedCues(for: audiobook.id)) ?? []
        subtitleCues = loaded.sorted {
            if $0.startTime != $1.startTime { return $0.startTime < $1.startTime }
            return $0.orderIndex < $1.orderIndex
        }
        savedSubtitleCueCount = subtitleCues.count

        var segments = (try? subtitleStore.sortedSegments(for: audiobook.id)) ?? []
        if segments.isEmpty, !subtitleCues.isEmpty {
            let inferred = SubtitleSegmentPlanner.inferredSegmentsFromLegacyCues(
                cues: subtitleCues,
                bookDuration: audiobook.duration
            )
            try? subtitleStore.insertInferredSegments(inferred, audiobook: audiobook)
            segments = (try? subtitleStore.sortedSegments(for: audiobook.id)) ?? inferred
        }
        subtitleSegments = segments
        savedSubtitleSegmentCount = subtitleSegments.count
    }

    private func refreshSubtitlePresentation(at playhead: TimeInterval? = nil) {
        guard isSubtitlesVisible else {
            subtitlePresentation = .hidden
            return
        }

        guard subtitlesSupported else {
            subtitlePresentation = .unavailable
            return
        }

        // Whole-book progress is shown in the subtitles sheet, not on the artwork overlay.
        if wholeBookJobState.isActive || activeGenerationScope == .wholeBook {
            subtitlePresentation = subtitleCues.isEmpty ? .needsGeneration : .ready
            return
        }

        switch audiobook?.subtitleGenerationStatus {
        case .inProgress where activeGenerationScope == .nearPlayhead:
            subtitlePresentation = .loading(subtitleProgressMessage ?? "Generating subtitles…")
            return
        case .failed where activeGenerationScope == .nearPlayhead:
            subtitlePresentation = .failed(subtitleProgressMessage ?? "Subtitle generation failed.")
            return
        case .complete, .partial, .failed, .inProgress, .notGenerated, .none:
            break
        }

        let resolvedPlayhead = playhead ?? audioEngine.currentTime

        if SubtitleCueResolver.resolveDisplayCueIndex(at: resolvedPlayhead, cues: subtitleCues) != nil {
            subtitlePresentation = .ready
            return
        }

        if activeGenerationScope == .nearPlayhead {
            subtitlePresentation = .loading(subtitleProgressMessage ?? "Generating subtitles…")
        } else if isScrubbing {
            subtitlePresentation = .ready
        } else {
            subtitlePresentation = .needsGeneration
        }
    }

    private func updateSubtitleDisplay(at time: TimeInterval) {
        guard isSubtitlesVisible else {
            subtitleLines = []
            return
        }

        let window = SubtitleCueResolver.visibleWindow(at: time, cues: subtitleCues)
        guard !window.cues.isEmpty else {
            subtitleLines = []
            return
        }
        let newLines = window.cues.enumerated().map { index, cue in
            SubtitleLineItem(
                orderIndex: cue.orderIndex,
                text: cue.text,
                startTime: cue.startTime,
                isActive: window.activeIndex == index
            )
        }
        guard newLines != subtitleLines else { return }
        subtitleLines = newLines
    }

    private func presentSubtitlesPaywall() {
        paywallFeature = .subtitles
        isPaywallPresented = true
    }

    private func presentEQPaywall() {
        paywallFeature = .eq
        isPaywallPresented = true
    }

    private func startSubtitleGeneration(scope: SubtitleGenerationScope) {
        guard let audiobook else { return }
        guard subtitlesSupported else {
            if scope == .nearPlayhead { subtitlePresentation = .unavailable }
            return
        }
        guard monetization.hasAccess(to: .subtitles) else {
            presentSubtitlesPaywall()
            return
        }
        if scope == .wholeBook, case .playing = playbackState {
            pause()
        }

        reloadSubtitleData(for: audiobook)

        if scope == .wholeBook {
            if !hasUncoveredSubtitleWindows {
                wholeBookJobState = .idle
                audiobook.subtitleGenerationStatus = .complete
                audiobook.subtitleLastCoveredEndTime = audiobook.duration
                try? modelContext.save()
                return
            }
        }

        cancelSubtitleGeneration()
        let generationID = subtitleGenerationEpoch
        activeGenerationScope = scope
        audiobook.subtitleGenerationScope = scope
        audiobook.subtitleGenerationStatus = .inProgress

        if scope == .wholeBook {
            wholeBookJobState = .preparing
        } else {
            isSubtitlesVisible = true
            subtitlePresentation = .loading("Preparing subtitles…")
        }
        try? modelContext.save()

        let bookID = audiobook.id
        let playhead = audioEngine.currentTime
        let bookDuration = audiobook.duration
        let locale = settings.subtitleLocaleIdentifier ?? Locale.current.identifier
        audiobook.subtitleLocaleIdentifier = locale
        let resolvedChapters = chapters.map { ResolvedChapter(from: $0) }
        let existingSegments = subtitleSegments

        let orchestrator = SubtitleGenerationOrchestrator(
            transcriptionService: subtitleTranscriptionService
        )
        subtitleOrchestrator = orchestrator

        subtitleGenerationTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await orchestrator.generate(
                    scope: scope,
                    playhead: playhead,
                    bookDuration: bookDuration,
                    chapters: resolvedChapters,
                    existingSegments: existingSegments,
                    localeIdentifier: locale,
                    onWindowComplete: { [weak self] window, cues in
                        await self?.persistSubtitleWindow(
                            window: window,
                            cues: cues,
                            bookID: bookID,
                            generationID: generationID
                        )
                    },
                    onProgress: { [weak self] progress in
                        Task { @MainActor in
                            guard let self, generationID == self.subtitleGenerationEpoch else { return }
                            self.handleSubtitleGenerationProgress(progress, scope: scope)
                        }
                    }
                )
                await MainActor.run {
                    guard generationID == self.subtitleGenerationEpoch else { return }
                    self.finishSubtitleGeneration(success: true, scope: scope, bookDuration: bookDuration)
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard generationID == self.subtitleGenerationEpoch else { return }
                    self.handleSubtitleGenerationCancelled(scope: scope)
                }
            } catch {
                await MainActor.run {
                    guard generationID == self.subtitleGenerationEpoch else { return }
                    self.handleSubtitleGenerationFailure(error, scope: scope, bookDuration: bookDuration)
                }
            }
        }
    }

    private func handleSubtitleGenerationProgress(
        _ progress: SubtitleGenerationProgress,
        scope: SubtitleGenerationScope
    ) {
        subtitleProgressMessage = progress.message
        switch scope {
        case .wholeBook:
            let total = progress.totalWindows ?? 1
            wholeBookJobState = .running(
                completed: progress.completedWindows,
                total: max(total, 1),
                message: progress.message
            )
        case .nearPlayhead:
            refreshSubtitlePresentation()
        }
    }

    private func handleSubtitleGenerationCancelled(scope: SubtitleGenerationScope) {
        subtitleProgressMessage = nil
        activeGenerationScope = nil
        subtitleGenerationTask = nil
        subtitleOrchestrator = nil

        switch scope {
        case .wholeBook:
            wholeBookJobState = .idle
            audiobook?.subtitleGenerationStatus = subtitleCues.isEmpty ? .notGenerated : .partial
        case .nearPlayhead:
            audiobook?.subtitleGenerationStatus = subtitleCues.isEmpty ? .notGenerated : .partial
            refreshSubtitlePresentation()
        }
        try? modelContext.save()
    }

    private func handleSubtitleGenerationFailure(
        _ error: Error,
        scope: SubtitleGenerationScope,
        bookDuration: TimeInterval
    ) {
        subtitleProgressMessage = error.localizedDescription
        activeGenerationScope = nil
        subtitleGenerationTask = nil
        subtitleOrchestrator = nil

        switch scope {
        case .wholeBook:
            wholeBookJobState = .failed(error.localizedDescription)
            audiobook?.subtitleGenerationStatus = subtitleCues.isEmpty ? .failed : .partial
        case .nearPlayhead:
            audiobook?.subtitleGenerationStatus = subtitleCues.isEmpty ? .failed : .partial
            refreshSubtitlePresentation()
            if audiobook?.subtitlesTranscribeAsYouGo == true {
                autoTranscribeBlockedUntilPlayhead = audioEngine.currentTime + SubtitleWindowPlanner.defaultWindowDuration
            }
        }
        try? modelContext.save()
        _ = bookDuration
    }

    @MainActor
    private func persistSubtitleWindow(
        window: SubtitleTimeWindow,
        cues: [SubtitleCueTiming],
        bookID: UUID,
        generationID: UInt64
    ) async {
        guard generationID == subtitleGenerationEpoch else { return }
        guard let audiobook, audiobook.id == bookID else { return }
        try? subtitleStore.insertSegment(window: window, audiobook: audiobook)
        try? subtitleStore.insertCues(cues, audiobook: audiobook)
        reloadSubtitleData(for: audiobook)
        audiobook.subtitleLastCoveredEndTime = max(audiobook.subtitleLastCoveredEndTime, window.globalEnd)
        audiobook.subtitleGenerationStatus = .partial
        try? modelContext.save()
        refreshSubtitlePresentation()
        updateSubtitleDisplay(at: audioEngine.currentTime)
    }

    private func finishSubtitleGeneration(
        success: Bool,
        scope: SubtitleGenerationScope,
        bookDuration: TimeInterval
    ) {
        guard let audiobook else { return }
        activeGenerationScope = nil
        subtitleGenerationTask = nil
        subtitleOrchestrator = nil
        subtitleProgressMessage = nil

        if success {
            let wholeBookComplete = !hasUncoveredSubtitleWindows
            if wholeBookComplete {
                audiobook.subtitleGenerationStatus = .complete
                audiobook.subtitleLastCoveredEndTime = bookDuration
            } else if subtitleCues.isEmpty, subtitleSegments.isEmpty {
                audiobook.subtitleGenerationStatus = .failed
            } else {
                audiobook.subtitleGenerationStatus = .partial
            }

            switch scope {
            case .wholeBook:
                wholeBookJobState = wholeBookComplete ? .idle : .idle
            case .nearPlayhead:
                refreshSubtitlePresentation()
            }
        } else {
            audiobook.subtitleGenerationStatus = subtitleCues.isEmpty ? .failed : .partial
            if scope == .nearPlayhead {
                refreshSubtitlePresentation()
            }
        }

        try? modelContext.save()
        updateSubtitleDisplay(at: audioEngine.currentTime)
    }

    private func cancelSubtitleGeneration() {
        subtitleGenerationEpoch &+= 1
        let scope = activeGenerationScope
        let orchestrator = subtitleOrchestrator
        subtitleGenerationTask?.cancel()
        subtitleGenerationTask = nil
        subtitleOrchestrator = nil
        activeGenerationScope = nil
        if scope == .wholeBook {
            wholeBookJobState = .idle
        }
        if orchestrator != nil {
            Task { await orchestrator?.cancel() }
        }
    }

    /// Re-anchors near-playhead generation when the listener jumps while subtitles are visible.
    private func handleSubtitlesPlayheadJump(to time: TimeInterval, from previous: TimeInterval) {
        guard isSubtitlesVisible, let audiobook else { return }
        guard previous != time else { return }

        guard subtitlesSupported, monetization.hasAccess(to: .subtitles) else { return }
        guard !wholeBookJobState.isActive else { return }

        let hasActiveCue = SubtitleCueResolver.hasActiveCue(at: time, cues: subtitleCues)

        if hasActiveCue {
            if activeGenerationScope == .nearPlayhead {
                cancelSubtitleGeneration()
                audiobook.subtitleGenerationStatus = subtitleCues.isEmpty ? .notGenerated : .partial
                try? modelContext.save()
            }
            refreshSubtitlePresentation(at: time)
            updateSubtitleDisplay(at: time)
            return
        }

        if activeGenerationScope == .nearPlayhead {
            cancelSubtitleGeneration()
        }
        startSubtitleGeneration(scope: .nearPlayhead)
    }

    private func maybeTriggerTranscribeAsYouGo(at time: TimeInterval) {
        guard isAppInForeground,
              isSubtitlesVisible,
              let audiobook,
              audiobook.subtitlesTranscribeAsYouGo,
              subtitlesSupported,
              monetization.hasAccess(to: .subtitles),
              activeGenerationScope == nil,
              !wholeBookJobState.isActive,
              case .playing = playbackState,
              time >= autoTranscribeBlockedUntilPlayhead
        else { return }

        guard SubtitleSegmentPlanner.shouldAutoGenerateNearPlayhead(
            playhead: time,
            bookDuration: audiobook.duration,
            segments: subtitleSegments,
            cues: subtitleCues
        ) else { return }

        autoTranscribeBlockedUntilPlayhead = time + SubtitleWindowPlanner.defaultWindowDuration
        startSubtitleGeneration(scope: .nearPlayhead)
    }

    private func suspendNearPlayheadSubtitleGenerationForBackground() {
        guard activeGenerationScope == .nearPlayhead else { return }
        cancelSubtitleGeneration()
        audiobook?.subtitleGenerationStatus = subtitleCues.isEmpty ? .notGenerated : .partial
        try? modelContext.save()
    }

    // MARK: - Lull Analysis

    func defaultSmartRewindOffsets(for range: SmartRewindRange) -> SmartRewindWindowOffsets {
        switch range {
        case .far:
            SmartRewindWindowOffsets(
                startOffset: settings.smartRewindFarStartOffset,
                endOffset: settings.smartRewindFarEndOffset
            )
        case .near:
            SmartRewindWindowOffsets(
                startOffset: settings.smartRewindNearStartOffset,
                endOffset: settings.smartRewindNearEndOffset
            )
        }
    }

    func analyzeSmartRewind(
        _ range: SmartRewindRange,
        customOffsets: SmartRewindWindowOffsets? = nil
    ) {
        guard case .idle = lullAnalysisState, audiobook != nil else { return }
        guard monetization.hasAccess(to: .paragraphBreaks) else {
            paywallFeature = .paragraphBreaks
            isPaywallPresented = true
            return
        }
        smartRewindSessionOffsets = customOffsets
        startSmartRewindAnalysis(range)
    }

    func lookAgainSmartRewind() {
        guard audiobook != nil else { return }
        guard monetization.hasAccess(to: .paragraphBreaks) else {
            paywallFeature = .paragraphBreaks
            isPaywallPresented = true
            return
        }
        guard case .results(let range, _) = lullAnalysisState else { return }
        startSmartRewindAnalysis(range)
    }

    func cancelLullAnalysis() {
        lullAnalysisState = .idle
        smartRewindSessionOffsets = nil
    }

    func seekToLull(_ lull: LullResult) {
        lullAnalysisState = .idle
        smartRewindSessionOffsets = nil
        endScrubbingForTransport()
        resetListeningSample()
        Task {
            try? await audioEngine.seek(to: max(0, lull.endTime - 0.5))
            syncDisplayFromEngine()
        }
    }

    /// Runs lull detection on iPhone for Watch remote commands.
    func analyzeLullsForWatch() async -> WatchLullResult? {
        guard audiobook != nil else { return nil }
        guard monetization.hasAccess(to: .paragraphBreaks) else { return nil }
        let (from, to) = lullAnalysisWindow()
        let chapters = audioEngine.resolvedChapters
        let lulls = (try? await lullDetector.findLulls(in: chapters, from: from, to: to)) ?? []
        guard let lull = lulls.first else { return nil }
        return WatchLullResult(endTime: lull.endTime, duration: lull.duration)
    }

    func seekToLullEndTime(_ endTime: TimeInterval) {
        endScrubbingForTransport()
        resetListeningSample()
        Task {
            try? await audioEngine.seek(to: max(0, endTime - 0.5))
            syncDisplayFromEngine()
            publishWatchSnapshot(immediate: true, includeArtwork: false)
        }
    }

    private func startSmartRewindAnalysis(_ range: SmartRewindRange) {
        lullAnalysisState = .analyzing(range)
        let (from, to) = smartRewindWindow(for: range)
        let chapters = audioEngine.resolvedChapters
        Task {
            let lulls = (try? await lullDetector.findLulls(
                in: chapters,
                from: from,
                to: to,
                maxResults: 3
            )) ?? []
            lullAnalysisState = .results(range, lulls)
        }
    }

    private func smartRewindWindow(for range: SmartRewindRange) -> (from: TimeInterval, to: TimeInterval) {
        let offsets = smartRewindSessionOffsets ?? defaultSmartRewindOffsets(for: range)
        return SmartRewindWindowPolicy.playbackWindow(
            currentTime: audioEngine.currentTime,
            offsets: offsets
        )
    }

    private func lullAnalysisWindow() -> (from: TimeInterval, to: TimeInterval) {
        let skipRecent = min(max(settings.lullSkipRecentWindow, 0), 5 * 60)
        let lookback = min(max(settings.lullLookbackWindow, 30), 15 * 60)
        let to = max(0, audioEngine.currentTime - skipRecent)
        let from = max(0, to - lookback)
        return (from, to)
    }

    // MARK: - Bookmarks

    func addBookmark() {
        guard let audiobook else { return }
        let bookmark = Bookmark(title: "", note: "", timestamp: audioEngine.currentTime, audiobook: audiobook)
        audiobook.bookmarks.append(bookmark)
        bookmarks = audiobook.bookmarks.sorted { $0.timestamp < $1.timestamp }
        try? modelContext.save()
    }

    /// Creates a bookmark at the current position and surfaces the edit sheet from PlayerView.
    func addBookmarkForEditing() {
        guard let audiobook else { return }
        let bookmark = Bookmark(title: "", note: "", timestamp: audioEngine.currentTime, audiobook: audiobook)
        audiobook.bookmarks.append(bookmark)
        bookmarks = audiobook.bookmarks.sorted { $0.timestamp < $1.timestamp }
        try? modelContext.save()
        pendingNewBookmark = bookmark
    }

    /// Creates a bookmark at a subtitle line's timestamp, titled with that line's text.
    func addBookmarkFromSubtitle(text: String, at startTime: TimeInterval) {
        guard let audiobook else { return }
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let bookmark = Bookmark(title: title, note: "", timestamp: startTime, audiobook: audiobook)
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

    func updateBookmark(_ bookmark: Bookmark, title: String, note: String, timestamp: TimeInterval) {
        bookmark.title = title
        bookmark.note = note
        bookmark.timestamp = timestamp
        bookmarks = audiobook?.bookmarks.sorted { $0.timestamp < $1.timestamp } ?? []
        try? modelContext.save()
    }

    func seekToBookmark(_ bookmark: Bookmark) {
        isBookmarksPresented = false
        endScrubbingForTransport()
        resetListeningSample()
        Task {
            try? await audioEngine.seek(to: bookmark.timestamp)
            syncDisplayFromEngine()
        }
    }

    // MARK: - Bookmark Export

    func exportText() -> String {
        guard let audiobook else { return "" }
        return BookmarkExportService.generateText(for: audiobook, bookmarks: bookmarks)
    }

    func exportCSV() -> String {
        guard let audiobook else { return "" }
        let dateStr = DateFormatter.localizedString(from: .now, dateStyle: .long, timeStyle: .none)
        var rows: [String] = []
        rows.append(csvEscape(audiobook.title) + ",,")
        rows.append(csvEscape(audiobook.author) + ",,")
        rows.append("\(Self.formatTime(audiobook.duration)),,")
        rows.append("\(dateStr),,")
        rows.append(",,")
        rows.append("Timestamp,Name,Note")

        for bm in bookmarks {
            let ts   = Self.formatTime(bm.timestamp)
            let name = csvEscape(bm.title)
            let note = csvEscape(bm.note)
            rows.append("\(ts),\(name),\(note)")
        }

        return rows.joined(separator: "\n")
    }

    func exportMarkdown() -> String {
        guard let audiobook else { return "" }
        let dateStr = DateFormatter.localizedString(from: .now, dateStyle: .long, timeStyle: .none)
        var lines: [String] = []

        lines.append("# \(audiobook.title) — Bookmarks")
        lines.append("")
        lines.append("| | |")
        lines.append("|---|---|")
        lines.append("| **Author** | \(mdEscape(audiobook.author)) |")
        lines.append("| **Length** | \(Self.formatTime(audiobook.duration)) |")
        lines.append("| **Exported** | \(dateStr) |")
        lines.append("")
        lines.append("| Timestamp | Name | Note |")
        lines.append("|-----------|------|------|")

        for bm in bookmarks {
            let name = mdEscape(bm.title)
            let note = mdEscape(bm.note)
            lines.append("| \(Self.formatTime(bm.timestamp)) | \(name) | \(note) |")
        }

        return lines.joined(separator: "\n")
    }

    private func csvEscape(_ s: String) -> String {
        guard s.contains(",") || s.contains("\"") || s.contains("\n") else { return s }
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private func mdEscape(_ s: String) -> String {
        s.replacingOccurrences(of: "|", with: "\\|")
    }

    // MARK: - Sleep Timer

    func setSleepTimer(_ option: SleepTimerOption) {
        sleepTimerCancellable?.cancel()
        sleepTimerCancellable = nil
        sleepTimerOption = option
        sleepTimerRemaining = 0

        switch option {
        case .off:
            settings.clearSleepTimer()

        case .endOfChapter:
            settings.saveSleepTimer(option: "endOfChapter", expiryDate: nil)

        case .minutes(let n):
            sleepTimerRemaining = TimeInterval(n * 60)
            let expiryDate = Date().addingTimeInterval(sleepTimerRemaining)
            settings.saveSleepTimer(option: "minutes(\(n))", expiryDate: expiryDate)
            startMinutesTimer()
        }

        syncChapterEndAutoAdvance()
    }

    private func syncChapterEndAutoAdvance() {
        audioEngine.shouldAutoAdvanceAtChapterEnd = sleepTimerOption != .endOfChapter
    }

    private func handleEndOfChapterSleepTimer(stoppingAfterChapterIndex index: Int) {
        guard sleepTimerOption == .endOfChapter else { return }
        guard index < chapters.count else { return }

        sleepTimerOption = .off
        settings.clearSleepTimer()
        syncChapterEndAutoAdvance()

        let chapterEnd = chapters[index].startTime + chapters[index].duration

        Task {
            if audioEngine.currentTime > chapterEnd + 0.05 {
                try? await audioEngine.seek(to: chapterEnd)
            }
            audioEngine.pause()
            savePlaybackPosition()
        }
    }

    private func startMinutesTimer() {
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
                    self.settings.clearSleepTimer()
                }
            }
    }

    /// Restores a persisted sleep timer after an app kill. Called once from `init`.
    private func restoreSleepTimer() {
        guard let saved = settings.loadSleepTimer() else { return }

        if saved.option == "endOfChapter" {
            sleepTimerOption = .endOfChapter
            syncChapterEndAutoAdvance()
            return
        }

        // Parse "minutes(N)" format
        if saved.option.hasPrefix("minutes("), saved.option.hasSuffix(")"),
           let n = Int(saved.option.dropFirst(8).dropLast()) {
            sleepTimerOption = .minutes(n)
            sleepTimerRemaining = saved.remaining
            startMinutesTimer()
        }
    }

    // MARK: - Scrubbing

    func beginScrubbing() {
        isScrubbing = true
        if isSubtitlesVisible, activeGenerationScope == .nearPlayhead {
            cancelSubtitleGeneration()
            audiobook?.subtitleGenerationStatus = subtitleCues.isEmpty ? .notGenerated : .partial
            try? modelContext.save()
        }
        previewSubtitlesAtScrubPosition()
    }

    func commitScrub() async {
        guard isScrubbing else {
            syncDisplayFromEngine()
            return
        }

        let targetTime = scrubTargetTime(for: scrubPosition)
        isScrubbing = false
        resetListeningSample()
        try? await audioEngine.seek(to: targetTime)
        syncDisplayFromEngine()
    }

    /// Realigns the scrubber and time labels with the engine after a seek or stuck scrub.
    private func syncDisplayFromEngine() {
        let previous = lastAppliedEngineTime
        let time = audioEngine.currentTime
        if let previous {
            handleSubtitlesPlayheadJump(to: time, from: previous)
        }
        applyEngineTime(time)
    }

    private func contentRemainingInterval() -> TimeInterval {
        switch playbackDisplayMode {
        case .entireBook:
            let duration = audioEngine.duration
            let elapsed = isScrubbing ? scrubPosition * duration : audioEngine.currentTime
            return max(0, duration - elapsed)
        case .currentChapter:
            let chaps = chapters
            guard !chaps.isEmpty else {
                let duration = audioEngine.duration
                let elapsed = isScrubbing ? scrubPosition * duration : audioEngine.currentTime
                return max(0, duration - elapsed)
            }
            let chapterDuration = chaps[currentChapterIndex].duration
            let chapterElapsed = isScrubbing
                ? scrubPosition * chapterDuration
                : max(0, audioEngine.currentTime - chaps[currentChapterIndex].startTime)
            return max(0, chapterDuration - chapterElapsed)
        }
    }

    /// Wall-clock duration at the current playback speed, e.g. "20:00" for 30:00 content at 1.5×.
    func formatSpeedAdjustedDuration(_ contentDuration: TimeInterval) -> String {
        let adjusted = contentDuration / Double(max(playbackSpeed, Self.minPlaybackSpeed))
        return Self.formatTime(adjusted)
    }

    private func formatSpeedAdjustedRemaining(_ contentRemaining: TimeInterval) -> String {
        "-\(formatSpeedAdjustedDuration(contentRemaining))"
    }

    private func scrubTargetTime(for position: Double) -> TimeInterval {
        switch playbackDisplayMode {
        case .entireBook:
            return position * audioEngine.duration
        case .currentChapter:
            let chaps = chapters
            guard !chaps.isEmpty else { return position * audioEngine.duration }
            let chapter = chaps[currentChapterIndex]
            return chapter.startTime + position * chapter.duration
        }
    }

    private func endScrubbingForTransport() {
        isScrubbing = false
    }

    // MARK: - Private — Engine Observation

    private func observeEngine() {
        audioEngine.currentTimePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] time in
                guard let self, !self.isScrubbing else { return }
                let prevChapterIndex = self.currentChapterIndex
                if case .playing = self.playbackState {
                    self.recordListeningProgress(at: time)
                }
                self.applyEngineTime(time)
                self.publishWatchSnapshot(immediate: false, includeArtwork: false)
                // Sleep-timer: endOfChapter — pause when the active chapter's end time is reached.
                if self.sleepTimerOption == .endOfChapter,
                   prevChapterIndex < self.chapters.count {
                    let chapterEnd = self.chapters[prevChapterIndex].startTime
                        + self.chapters[prevChapterIndex].duration
                    if time >= chapterEnd {
                        self.handleEndOfChapterSleepTimer(stoppingAfterChapterIndex: prevChapterIndex)
                    }
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
                    self.resetListeningSample()
                    self.stopPositionSaveTimer()
                    self.savePlaybackPosition()
                    if case .finished = state {
                        if self.sleepTimerOption == .endOfChapter {
                            self.sleepTimerOption = .off
                            self.settings.clearSleepTimer()
                            self.syncChapterEndAutoAdvance()
                        }
                        if !self.didReportNaturalFinish,
                           let book = self.audiobook {
                            self.didReportNaturalFinish = true
                            self.onNaturalFinish?(book)
                        }
                    }
                default:
                    self.resetListeningSample()
                    self.stopPositionSaveTimer()
                }
                self.publishWatchSnapshot(immediate: true, includeArtwork: false)
            }
            .store(in: &cancellables)
    }

    // MARK: - Watch Sync

    func watchSnapshotForReply(
        includeArtwork: Bool = false,
        systemVolumeOverride: Float? = nil
    ) -> WatchPlaybackSnapshot {
        makeWatchSnapshot(
            revision: watchRevision,
            includeArtwork: includeArtwork,
            systemVolumeOverride: systemVolumeOverride
        )
    }

    private func publishWatchSnapshot(immediate: Bool, includeArtwork: Bool) {
        guard let watchBridge else { return }
        let now = Date()
        if !immediate, now.timeIntervalSince(lastWatchPublishTime) < 1.0 { return }
        lastWatchPublishTime = now
        watchRevision += 1
        let bookChanged = audiobook?.id != lastPublishedBookID
        let shouldIncludeArtwork = includeArtwork || bookChanged
        if bookChanged { lastPublishedBookID = audiobook?.id }
        let snapshot = makeWatchSnapshot(revision: watchRevision, includeArtwork: shouldIncludeArtwork)
        watchBridge.publishSnapshot(snapshot, includeArtwork: shouldIncludeArtwork)
    }

    private func makeWatchSnapshot(
        revision: UInt64,
        includeArtwork: Bool,
        systemVolumeOverride: Float? = nil
    ) -> WatchPlaybackSnapshot {
        WatchSnapshotBuilder.makeSnapshot(
            revision: revision,
            audiobook: audiobook,
            chapters: chapters,
            currentChapterIndex: currentChapterIndex,
            playbackState: audioEngine.playbackState,
            playbackSpeed: playbackSpeed,
            skipForwardSeconds: settings.skipForwardInterval,
            skipBackwardSeconds: settings.skipBackwardInterval,
            globalTime: audioEngine.currentTime,
            globalDuration: audioEngine.duration,
            playbackTimelineScope: playbackDisplayMode.timelineScope,
            coverImage: coverImage,
            includeArtwork: includeArtwork,
            systemVolumeOverride: systemVolumeOverride
        )
    }

    private func applyEngineTime(_ time: TimeInterval) {
        lastAppliedEngineTime = time

        let duration = audioEngine.duration
        let newIndex = resolveChapterIndex(for: time)
        if newIndex != currentChapterIndex { currentChapterIndex = newIndex }

        if isSubtitlesVisible {
            updateSubtitleDisplay(at: time)
        }

        maybeTriggerTranscribeAsYouGo(at: time)

        let newScrub: Double
        let newCurrent: String

        switch playbackDisplayMode {
        case .entireBook:
            newScrub    = duration > 0 ? min(1, time / duration) : 0
            newCurrent  = Self.formatTime(time)

        case .currentChapter:
            if chapters.isEmpty {
                newScrub    = duration > 0 ? min(1, time / duration) : 0
                newCurrent  = Self.formatTime(time)
            } else {
                let chapter = chapters[newIndex]
                let elapsed = max(0, time - chapter.startTime)
                let dur     = chapter.duration
                newScrub    = dur > 0 ? min(1, elapsed / dur) : 0
                newCurrent  = Self.formatTime(elapsed)
            }
        }

        // scrubPosition drives the slider and must update every tick for smooth motion.
        // The elapsed label only changes once per second — skip the write when unchanged
        // to avoid invalidating views that only read that label.
        scrubPosition = newScrub
        if displayCurrentTime != newCurrent { displayCurrentTime = newCurrent }
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

    // MARK: - Private — Listening Time

    /// Credits small forward timeline advances that occur while playback is running.
    /// Large jumps (scrubs, skips, chapter seeks) are ignored so stats reflect real listening.
    private func recordListeningProgress(at position: TimeInterval) {
        guard let audiobook else {
            lastListenedPositionSample = position
            return
        }

        defer { lastListenedPositionSample = position }

        guard let previous = lastListenedPositionSample else { return }

        let delta = position - previous
        guard delta > 0 else { return }

        // Observer fires every ~0.5 s; allow headroom for the current playback speed.
        let maxDelta = Self.listeningSampleInterval * Double(playbackSpeed) * 1.25 + 0.1
        guard delta <= maxDelta else { return }

        audiobook.accumulatedListeningSeconds += delta
        WidgetSnapshotWriter.recordListeningDelta(delta)
    }

    private func resetListeningSample() {
        lastListenedPositionSample = nil
    }

    // MARK: - Private — Playback Speed

    private func playbackSpeedForLoad(of audiobook: Audiobook) -> Float {
        if settings.universalPlaybackSpeedEnabled {
            let speed = settings.universalPlaybackSpeed > 0
                ? settings.universalPlaybackSpeed
                : settings.defaultSpeed
            if settings.universalPlaybackSpeed <= 0 {
                settings.universalPlaybackSpeed = speed
            }
            return speed
        }
        if let perBook = audiobook.lastPlaybackSpeed, perBook > 0 {
            return perBook
        }
        return settings.defaultSpeed
    }

    // MARK: - Private — Persistence

    private func widgetProgress(for audiobook: Audiobook, at time: TimeInterval? = nil) -> Double {
        WidgetListeningSnapshot.playbackProgress(
            currentTime: time ?? audiobook.currentPlaybackTime,
            duration: audiobook.duration
        )
    }

    private func savePlaybackPosition(isPeriodicSave: Bool = false) {
        guard let audiobook else { return }
        audiobook.currentPlaybackTime = audioEngine.currentTime
        audiobook.lastPlayedAt = .now
        try? modelContext.save()
        WidgetSnapshotWriter.updateLastPlayed(
            title: audiobook.title,
            author: audiobook.author,
            audiobookID: audiobook.id,
            progress: widgetProgress(for: audiobook, at: audioEngine.currentTime)
        )
        onPlaybackPositionSaved?(isPeriodicSave)
    }

    private func startPositionSaveTimer() {
        guard positionSaveTimer == nil else { return }
        positionSaveTimer = Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.savePlaybackPosition(isPeriodicSave: true) }
    }

    private func stopPositionSaveTimer() {
        positionSaveTimer?.cancel()
        positionSaveTimer = nil
    }

    private func installBackgroundObserver() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppWillResignActive()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.handleAppDidBecomeActive()
            }
            .store(in: &cancellables)
    }

    private func handleAppWillResignActive() {
        isAppInForeground = false
        savePlaybackPosition()
        suspendNearPlayheadSubtitleGenerationForBackground()
    }

    private func handleAppDidBecomeActive() {
        isAppInForeground = true
        if isSubtitlesVisible {
            refreshSubtitlePresentation()
            updateSubtitleDisplay(at: audioEngine.currentTime)
        }
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

private extension PlayerViewModel.PlaybackDisplayMode {
    var nowPlayingScope: NowPlayingTimelineScope {
        switch self {
        case .entireBook: return .entireBook
        case .currentChapter: return .currentChapter
        }
    }

    var timelineScope: PlaybackTimelineScope {
        switch self {
        case .entireBook: return .entireBook
        case .currentChapter: return .currentChapter
        }
    }

    init(scope: PlaybackTimelineScope) {
        switch scope {
        case .entireBook: self = .entireBook
        case .currentChapter: self = .currentChapter
        }
    }
}

private extension PlaybackTimelineScope {
    var nowPlayingScope: NowPlayingTimelineScope {
        switch self {
        case .entireBook: return .entireBook
        case .currentChapter: return .currentChapter
        }
    }
}

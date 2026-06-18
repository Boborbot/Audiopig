//
//  WatchPlayerViewModel.swift
//  AudiopigWatch
//

import Foundation
import UIKit
import Combine

enum WatchLullState: Equatable {
    case idle
    case analyzing
    case result(WatchLullResult)
    case empty
    case unavailable(String)
}

@MainActor
final class WatchPlayerViewModel: ObservableObject {
    @Published private(set) var snapshot: WatchPlaybackSnapshot = .idle
    @Published private(set) var isReachable = false
    @Published private(set) var connectionMessage: String?
    @Published private(set) var chapters: [WatchChapterSummary] = []
    @Published var artworkSkipGesturesEnabled = false
    @Published var watchArtworkViewMode: WatchArtworkViewMode = .off
    @Published private(set) var speedPresets: [Float] = WatchSpeedRange.presets
    @Published private(set) var playbackTimelineScope: PlaybackTimelineScope = WatchPlayerViewModel.loadPersistedTimelineScope()

    /// Optimistic transport state for instant button feedback.
    @Published private(set) var optimisticState: WatchPlaybackState?

    @Published var speedDraft: Float = 1.0
    @Published var volumeDraft: Float = 0.5
    @Published var showVolumeOverlay = false
    @Published private(set) var lullState: WatchLullState = .idle
    @Published private(set) var hasParagraphBreaksAccess = false
    @Published private(set) var hasWatchArtworkViewAccess = false

    private let coordinator: any WatchPlaybackCoordinating
    private let client: WatchConnectivityClient
    private var interpolationTimer: Timer?
    private var lastAuthoritativeSnapshot: WatchPlaybackSnapshot = .idle
    private var lastSentSpeed: Float?
    private var lastSentVolume: Float?
    private var lastVolumeAdjustmentTime: Date?
    private var lastVolumeSendTime: Date?
    private var pendingVolume: Float?
    private var volumeSendTask: Task<Void, Never>?
    private var volumeOverlayTask: Task<Void, Never>?
    private var lastVolumeHapticTime: Date?

    init(coordinator: any WatchPlaybackCoordinating, client: WatchConnectivityClient) {
        self.coordinator = coordinator
        self.client = client

        coordinator.setSnapshotHandler { [weak self] incoming in
            self?.applyAuthoritativeSnapshot(incoming)
        }

        client.setChaptersHandler { [weak self] payload in
            self?.applyChapters(payload)
        }

        client.setSettingsHandler { [weak self] settings in
            self?.applySettings(settings)
        }

        isReachable = coordinator.isReachable
        if let cachedSettings = client.latestSettings {
            applySettings(cachedSettings)
        }
        if let existing = coordinator.snapshot {
            applyAuthoritativeSnapshot(existing)
        }
        if let cachedChapters = client.latestChapters {
            applyChapters(cachedChapters)
        }

        if let router = coordinator as? WatchPlaybackRouter {
            router.setChaptersHandler { [weak self] payload in
                self?.applyChapters(payload)
            }
        }
    }

    var shouldLaunchToPlayer: Bool {
        guard snapshot.bookID != nil else { return false }
        switch snapshot.playbackState {
        case .playing, .paused, .loading:
            return true
        case .idle, .finished, .failed:
            return false
        }
    }

    var showsRemoteLullDetection: Bool {
        snapshot.bookID != nil
            && snapshot.source == .remote
            && hasParagraphBreaksAccess
    }

    var effectiveArtworkViewMode: WatchArtworkViewMode {
        guard hasWatchArtworkViewAccess else { return .off }
        return watchArtworkViewMode
    }

    /// Default pager page for the main transport controls (media or artwork-replace).
    var mainControlsPageIndex: Int {
        switch effectiveArtworkViewMode {
        case .off, .replaceStandardControls:
            return 1
        case .add:
            return 2
        }
    }

    var chaptersPageIndex: Int {
        switch effectiveArtworkViewMode {
        case .off, .replaceStandardControls:
            return 2
        case .add:
            return 3
        }
    }

    func lullLabel(for lull: WatchLullResult) -> String {
        let delta = max(0, interpolatedGlobalTime - lull.endTime)
        let secs = Int(delta)
        return String(format: "-%d:%02d", secs / 60, secs % 60)
    }

    func analyzeLulls() {
        guard showsRemoteLullDetection, isActive else { return }
        guard case .idle = lullState else { return }
        lullState = .analyzing
        Task {
            let result = await coordinator.send(.analyzeLulls)
            await handleLullCommandResult(result)
        }
    }

    func seekToLull(_ lull: WatchLullResult) {
        lullState = .idle
        WatchHaptics.directionUp()
        Task {
            let result = await coordinator.send(.seekToLull(endTime: lull.endTime))
            await handleCommandResult(result)
        }
    }

    func cancelLullAnalysis() {
        lullState = .idle
    }

    func retryLullAnalysis() {
        lullState = .idle
        analyzeLulls()
    }

    var displayState: WatchPlaybackState {
        optimisticState ?? snapshot.playbackState
    }

    var isActive: Bool {
        snapshot.bookID != nil && snapshot.playbackState.isActive
            || snapshot.bookID != nil && displayState.isActive
    }

    var chapterElapsedDisplay: TimeInterval {
        resolvedChapterProgress.chapterElapsed
    }

    var chapterRemainingDisplay: TimeInterval {
        max(0, resolvedChapterProgress.chapterDuration - resolvedChapterProgress.chapterElapsed)
    }

    var chapterProgressDisplay: Double {
        resolvedChapterProgress.chapterProgress
    }

    var timebarElapsedDisplay: TimeInterval {
        usesChapterTimebar
            ? resolvedChapterProgress.chapterElapsed
            : interpolatedGlobalTime
    }

    var timebarRemainingDisplay: TimeInterval {
        if usesChapterTimebar {
            let progress = resolvedChapterProgress
            return max(0, progress.chapterDuration - progress.chapterElapsed)
        }
        return max(0, snapshot.globalDuration - interpolatedGlobalTime)
    }

    var timebarProgressDisplay: Double {
        if usesChapterTimebar {
            return resolvedChapterProgress.chapterProgress
        }
        guard snapshot.globalDuration > 0 else { return 0 }
        return min(1, interpolatedGlobalTime / snapshot.globalDuration)
    }

    var artworkImage: UIImage? {
        guard let data = snapshot.artworkJPEG else { return nil }
        return UIImage(data: data)
    }

    var skipForwardInterval: Int { Int(snapshot.skipForwardSeconds) }
    var skipBackwardInterval: Int { Int(snapshot.skipBackwardSeconds) }

    var speedLabel: String {
        WatchSpeedRange.formatLabel(speedDraft)
    }

    func refresh() async {
        let result = await coordinator.send(.requestSnapshot)
        if let snap = result.snapshot {
            applyAuthoritativeSnapshot(snap)
        }
        isReachable = coordinator.isReachable
    }

    func togglePlayPause() {
        switch displayState {
        case .playing:
            optimisticState = .paused
            WatchHaptics.pause()
        default:
            optimisticState = .playing
            WatchHaptics.play()
        }
        Task {
            let result = await coordinator.send(.togglePlayPause)
            await handleCommandResult(result)
        }
    }

    func skipForward() {
        WatchHaptics.directionUp()
        bumpInterpolatedGlobal(by: snapshot.skipForwardSeconds)
        Task {
            let result = await coordinator.send(.skipForward)
            await handleCommandResult(result)
        }
    }

    func skipBackward() {
        WatchHaptics.directionDown()
        bumpInterpolatedGlobal(by: -snapshot.skipBackwardSeconds)
        Task {
            let result = await coordinator.send(.skipBackward)
            await handleCommandResult(result)
        }
    }

    func applySpeedDraft() {
        let normalized = Self.normalizedSpeed(speedDraft)
        speedDraft = normalized
        guard lastSentSpeed != normalized else { return }
        lastSentSpeed = normalized
        WatchHaptics.click()
        Task {
            let result = await coordinator.send(.setSpeed(normalized))
            await handleCommandResult(result)
        }
    }

    func selectSpeedPreset(_ preset: Float) {
        speedDraft = preset
        applySpeedDraft()
    }

    var isVolumeAdjustmentActive: Bool {
        guard let lastVolumeAdjustmentTime else { return false }
        return Date().timeIntervalSince(lastVolumeAdjustmentTime) < 0.5
    }

    func applyVolumeDraft() {
        let normalized = WatchVolumeRange.normalized(volumeDraft)
        volumeDraft = normalized
        pendingVolume = normalized
        lastVolumeAdjustmentTime = Date()
        showVolumeOverlay = true
        let now = Date()
        if lastVolumeHapticTime == nil || now.timeIntervalSince(lastVolumeHapticTime!) >= 0.12 {
            lastVolumeHapticTime = now
            WatchHaptics.click()
        }
        volumeOverlayTask?.cancel()
        volumeOverlayTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            showVolumeOverlay = false
        }
        scheduleVolumeSend()
    }

    func seekToChapter(at index: Int) {
        guard chapters.indices.contains(index) else { return }
        WatchHaptics.directionUp()
        Task {
            let result = await coordinator.send(.seekToChapterIndex(index))
            await handleCommandResult(result)
        }
    }

    func seekToChapter(id: UUID) {
        WatchHaptics.directionUp()
        Task {
            let result = await coordinator.send(.seekToChapter(id: id))
            await handleCommandResult(result)
        }
    }

    func handleArtworkDoubleTap() {
        guard artworkSkipGesturesEnabled else { return }
        skipForward()
    }

    func handleArtworkTripleTap() {
        guard artworkSkipGesturesEnabled else { return }
        skipBackward()
    }

    func sendArtworkGesturesSetting(_ enabled: Bool) async -> WatchCommandResult {
        await coordinator.send(.setArtworkSkipGesturesEnabled(enabled))
    }

    func sendWatchArtworkViewModeSetting(_ mode: WatchArtworkViewMode) async -> WatchCommandResult {
        await coordinator.send(.setWatchArtworkViewMode(mode))
    }

    func preferLocalPlayback(_ preferred: Bool) {
        (coordinator as? WatchPlaybackRouter)?.preferLocalPlayback(preferred)
    }

    private func applyAuthoritativeSnapshot(_ incoming: WatchPlaybackSnapshot) {
        if WatchSnapshotFreshness.shouldReject(incoming: incoming, comparedTo: lastAuthoritativeSnapshot) {
            return
        }

        let bookChanged = incoming.bookID != lastAuthoritativeSnapshot.bookID
            || incoming.source != lastAuthoritativeSnapshot.source
        lastAuthoritativeSnapshot = incoming
        snapshot = incoming
        optimisticState = nil
        connectionMessage = nil
        interpolatedGlobalTime = incoming.globalCurrentTime
        isReachable = coordinator.isReachable

        if let scope = incoming.playbackTimelineScope {
            applyTimelineScope(scope)
        }

        if bookChanged {
            lullState = .idle
            if let cached = client.latestChapters, cached.bookID == incoming.bookID {
                applyChapters(cached)
            } else {
                chapters = []
            }
            lastSentVolume = nil
            pendingVolume = nil
            lastVolumeAdjustmentTime = nil
            volumeDraft = WatchVolumeRange.normalized(incoming.systemVolume)
        }

        reconcileSpeed(from: incoming.playbackSpeed)
        if !bookChanged {
            reconcileVolume(from: incoming.systemVolume)
        }
        restartInterpolationIfNeeded()
    }

    private func reconcileSpeed(from phoneSpeed: Float) {
        let tolerance = WatchSpeedRange.step / 2
        if let pending = lastSentSpeed {
            if abs(phoneSpeed - pending) <= tolerance {
                speedDraft = phoneSpeed
                lastSentSpeed = nil
            }
        } else if abs(speedDraft - phoneSpeed) > tolerance {
            speedDraft = phoneSpeed
        }
    }

    private func reconcileVolume(from phoneVolume: Float) {
        let normalized = WatchVolumeRange.normalized(phoneVolume)
        let tolerance = WatchVolumeRange.tolerance

        if pendingVolume != nil {
            return
        }

        if isVolumeAdjustmentActive {
            return
        }

        if let sent = lastSentVolume {
            if abs(normalized - sent) <= tolerance {
                volumeDraft = normalized
                lastSentVolume = nil
            }
            return
        }

        if abs(volumeDraft - normalized) > tolerance {
            volumeDraft = normalized
        }
    }

    private func handleLullCommandResult(_ result: WatchCommandResult) async {
        isReachable = coordinator.isReachable
        if let snap = result.snapshot {
            applyAuthoritativeSnapshot(snap)
        }

        if !result.success {
            lullState = .unavailable(result.errorMessage ?? "Unavailable on iPhone")
            WatchHaptics.error()
            return
        }

        if let lull = result.lullResult {
            lullState = .result(lull)
            WatchHaptics.click()
        } else {
            lullState = .empty
        }
    }

    private func applyChapters(_ payload: WatchChaptersPayload) {
        guard payload.bookID == snapshot.bookID || snapshot.bookID == nil else { return }
        chapters = payload.chapters.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func applySettings(_ settings: WatchSettingsSnapshot) {
        artworkSkipGesturesEnabled = settings.artworkSkipGesturesEnabled
        hasParagraphBreaksAccess = settings.hasParagraphBreaksAccess ?? false
        hasWatchArtworkViewAccess = settings.hasWatchArtworkViewAccess ?? false
        if !hasParagraphBreaksAccess {
            lullState = .idle
        }
        if let mode = settings.watchArtworkViewMode {
            watchArtworkViewMode = hasWatchArtworkViewAccess ? mode : .off
        } else if !hasWatchArtworkViewAccess {
            watchArtworkViewMode = .off
        }
        if let incomingPresets = settings.speedPresets, !incomingPresets.isEmpty {
            speedPresets = incomingPresets.sorted()
        } else {
            speedPresets = WatchSpeedRange.presets
        }
        if let scope = settings.playbackTimelineScope, snapshot.bookID == nil {
            // Only adopt settings scope before playback snapshots arrive; snapshots are authoritative.
            applyTimelineScope(scope)
        }
    }

    private func handleCommandResult(_ result: WatchCommandResult) async {
        isReachable = coordinator.isReachable
        if let snap = result.snapshot {
            applyAuthoritativeSnapshot(snap)
        } else if !result.success {
            optimisticState = nil
            lastSentSpeed = nil
            lastSentVolume = nil
            reconcileSpeed(from: snapshot.playbackSpeed)
            connectionMessage = result.errorMessage ?? client.connectionErrorMessage
            WatchHaptics.error()
        }
    }

    private func scheduleVolumeSend() {
        let now = Date()
        let minInterval: TimeInterval = 0.1

        if let last = lastVolumeSendTime, now.timeIntervalSince(last) < minInterval {
            volumeSendTask?.cancel()
            volumeSendTask = Task {
                let delay = minInterval - now.timeIntervalSince(lastVolumeSendTime!)
                try? await Task.sleep(for: .seconds(delay))
                guard !Task.isCancelled else { return }
                await sendPendingVolume()
            }
            return
        }

        volumeSendTask?.cancel()
        volumeSendTask = Task {
            await sendPendingVolume()
        }
    }

    private func sendPendingVolume() async {
        guard let volume = pendingVolume else { return }
        pendingVolume = nil
        lastVolumeSendTime = Date()
        lastSentVolume = volume
        let result = await coordinator.send(.setVolume(volume))
        await handleCommandResult(result)
    }

    private static func normalizedSpeed(_ speed: Float) -> Float {
        WatchSpeedRange.normalized(speed)
    }

    // MARK: - Local interpolation

    private var interpolatedGlobalTime: TimeInterval = 0

    /// Whether the timebar shows chapter-scoped elapsed/remaining.
    private var usesChapterTimebar: Bool {
        if snapshot.playbackTimelineScope == .currentChapter { return true }
        if playbackTimelineScope == .currentChapter { return true }
        return effectiveChapterCount > 1
    }

    private var effectiveChapterCount: Int {
        max(chapters.count, snapshot.chapterCount)
    }

    private var chapterTimings: [WatchChapterTiming] {
        if !chapters.isEmpty {
            return chapters.map { WatchChapterTiming(startTime: $0.startTime, duration: $0.duration) }
        }
        return []
    }

    private var resolvedChapterProgress: WatchChapterProgress {
        let timings = chapterTimings
        if !timings.isEmpty {
            return ChapterProgressCalculator.progress(
                globalTime: interpolatedGlobalTime,
                chapters: timings
            )
        }

        return WatchChapterProgress(
            chapterIndex: snapshot.chapterIndex,
            chapterElapsed: snapshot.chapterElapsed,
            chapterDuration: snapshot.chapterDuration,
            chapterProgress: snapshot.chapterProgress
        )
    }

    private func applyTimelineScope(_ scope: PlaybackTimelineScope) {
        guard playbackTimelineScope != scope else { return }
        playbackTimelineScope = scope
        Self.persistTimelineScope(scope)
    }

    private func bumpInterpolatedGlobal(by delta: TimeInterval) {
        interpolatedGlobalTime = max(0, min(snapshot.globalDuration, interpolatedGlobalTime + delta))
        objectWillChange.send()
    }

    private func restartInterpolationIfNeeded() {
        interpolationTimer?.invalidate()
        interpolationTimer = nil
        guard snapshot.playbackState == .playing else { return }
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.snapshot.playbackState == .playing else { return }
                let delta = 0.25 * Double(self.snapshot.playbackSpeed)
                self.bumpInterpolatedGlobal(by: delta)
            }
        }
    }
}

private extension WatchPlayerViewModel {
    static let timelineScopeDefaultsKey = "watch.playbackTimelineScope"

    static func loadPersistedTimelineScope() -> PlaybackTimelineScope {
        guard let raw = UserDefaults.standard.string(forKey: timelineScopeDefaultsKey),
              let scope = PlaybackTimelineScope(rawValue: raw) else {
            return .currentChapter
        }
        return scope
    }

    static func persistTimelineScope(_ scope: PlaybackTimelineScope) {
        UserDefaults.standard.set(scope.rawValue, forKey: timelineScopeDefaultsKey)
    }
}

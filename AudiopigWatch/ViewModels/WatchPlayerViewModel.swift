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

    /// Optimistic transport state for instant button feedback.
    @Published private(set) var optimisticState: WatchPlaybackState?

    private enum PendingTransportState: Equatable {
        case playing
        case paused
    }

    private var pendingTransportState: PendingTransportState?
    private var pendingTransportStartedAt: Date?

    @Published var speedDraft: Float = 1.0
    @Published var volumeDraft: Float = 0.5
    @Published var showVolumeOverlay = false
    @Published private(set) var lullState: WatchLullState = .idle
    @Published private(set) var hasParagraphBreaksAccess = false
    @Published private(set) var hasWatchArtworkViewAccess = false

    /// Bumps on each interpolation step so SwiftUI re-reads timebar computed values.
    @Published private(set) var playbackTick: UInt = 0

    private let coordinator: any WatchPlaybackCoordinating
    private let client: WatchConnectivityClient
    private var interpolationCancellable: AnyCancellable?
    private var remoteSyncTask: Task<Void, Never>?
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
        if let existing = coordinator.snapshot {
            applyAuthoritativeSnapshot(existing)
        }
        if let cachedChapters = client.latestChapters {
            applyChapters(cachedChapters)
        }
        if let cachedSettings = client.latestSettings {
            applySettings(cachedSettings)
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
        interpolatedChapterElapsed
    }

    var chapterRemainingDisplay: TimeInterval {
        max(0, snapshot.chapterDuration - interpolatedChapterElapsed)
    }

    var chapterProgressDisplay: Double {
        guard snapshot.chapterDuration > 0 else { return 0 }
        return min(1, interpolatedChapterElapsed / snapshot.chapterDuration)
    }

    var timebarElapsedDisplay: TimeInterval {
        timebarUsesChapterScope ? interpolatedChapterElapsed : interpolatedGlobalTime
    }

    var timebarRemainingDisplay: TimeInterval {
        if timebarUsesChapterScope {
            return max(0, snapshot.chapterDuration - interpolatedChapterElapsed)
        }
        return max(0, snapshot.globalDuration - interpolatedGlobalTime)
    }

    var timebarProgressDisplay: Double {
        if timebarUsesChapterScope {
            return chapterProgressDisplay
        }
        guard snapshot.globalDuration > 0 else { return 0 }
        return min(1, interpolatedGlobalTime / snapshot.globalDuration)
    }

    /// Chapter-scoped timebar when iPhone is in chapter mode, or for multi-chapter books.
    private var timebarUsesChapterScope: Bool {
        snapshot.playbackTimelineScope == .currentChapter || snapshot.chapterCount > 1
    }

    var artworkImage: UIImage? {
        guard let data = snapshot.artworkJPEG else { return nil }
        return UIImage(data: data)
    }

    var skipForwardInterval: Int { Int(snapshot.skipForwardSeconds) }
    var skipBackwardInterval: Int { Int(snapshot.skipBackwardSeconds) }

    func formatSpeedAdjustedDuration(_ contentDuration: TimeInterval) -> String {
        let adjusted = contentDuration / Double(max(snapshot.playbackSpeed, WatchSpeedRange.min))
        return WatchTimeFormat.format(adjusted)
    }

    var speedLabel: String {
        WatchSpeedRange.formatLabel(speedDraft)
    }

    func refresh() async {
        let result = await coordinator.send(.requestSnapshot)
        if let snap = result.snapshot {
            applyAuthoritativeSnapshot(snap)
        }
        if let cachedChapters = client.latestChapters {
            applyChapters(cachedChapters)
        }
        isReachable = coordinator.isReachable
    }

    func requestChaptersIfNeeded() async {
        guard snapshot.bookID != nil else { return }
        guard chapters.isEmpty || client.latestChapters?.bookID != snapshot.bookID else { return }
        let result = await coordinator.send(.requestChapters)
        if let payload = result.chapters {
            applyChapters(payload)
        }
    }

    /// Called when the Watch app returns to the foreground so timers and phone position resync.
    func handleSceneBecameActive() {
        refreshInterpolatedTimesFromWallClock()
        restartInterpolationIfNeeded()
        guard snapshot.source == .remote, snapshot.bookID != nil else { return }
        Task { await refresh() }
    }

    /// Fetches cover art from iPhone when artwork view is enabled but the cached JPEG was stripped.
    func ensureArtworkLoaded() async {
        guard effectiveArtworkViewMode != .off, artworkImage == nil, snapshot.bookID != nil else { return }
        let result = await coordinator.send(.requestSnapshot)
        if let snap = result.snapshot {
            applyAuthoritativeSnapshot(snap)
        }
    }

    func togglePlayPause() {
        let target: WatchPlaybackState
        switch displayState {
        case .playing:
            target = .paused
            pendingTransportState = .paused
            pendingTransportStartedAt = .now
            WatchHaptics.pause()
        default:
            target = .playing
            pendingTransportState = .playing
            pendingTransportStartedAt = .now
            WatchHaptics.play()
        }
        optimisticState = target
        restartInterpolationIfNeeded()
        Task {
            let result = await coordinator.send(.togglePlayPause)
            await handleCommandResult(result)
        }
    }

    func skipForward() {
        WatchHaptics.directionUp()
        bumpInterpolatedTimes(by: snapshot.skipForwardSeconds)
        Task {
            let result = await coordinator.send(.skipForward)
            await handleCommandResult(result)
        }
    }

    func skipBackward() {
        WatchHaptics.directionDown()
        bumpInterpolatedTimes(by: -snapshot.skipBackwardSeconds)
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

        var resolvedSnapshot = incoming
        if let pending = pendingTransportState {
            let pendingExpired = pendingTransportStartedAt.map {
                Date().timeIntervalSince($0) > Self.pendingTransportTimeout
            } ?? true
            if pendingExpired || transportStateMatches(pending, incoming.playbackState) {
                pendingTransportState = nil
                pendingTransportStartedAt = nil
                optimisticState = nil
            } else {
                let optimistic = watchState(for: pending)
                resolvedSnapshot = incoming.withPlaybackState(optimistic)
                optimisticState = optimistic
            }
        } else {
            optimisticState = nil
        }

        if !bookChanged,
           resolvedSnapshot.artworkJPEG == nil,
           resolvedSnapshot.bookID != nil {
            let cachedArtwork = snapshot.artworkJPEG ?? lastAuthoritativeSnapshot.artworkJPEG
            if let cachedArtwork {
                resolvedSnapshot = resolvedSnapshot.withArtworkJPEG(cachedArtwork)
            }
        }

        lastAuthoritativeSnapshot = resolvedSnapshot
        snapshot = resolvedSnapshot
        connectionMessage = nil
        syncInterpolationAnchors(
            global: incoming.globalCurrentTime,
            chapterElapsed: incoming.chapterElapsed
        )
        isReachable = coordinator.isReachable

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
        updateRemoteSyncPolling()
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
        if effectiveArtworkViewMode != .off,
           artworkImage == nil,
           snapshot.bookID != nil,
           snapshot.playbackState == .playing || snapshot.playbackState == .paused {
            Task { await ensureArtworkLoaded() }
        }
        if let incomingPresets = settings.speedPresets, !incomingPresets.isEmpty {
            speedPresets = incomingPresets.sorted()
        } else {
            speedPresets = WatchSpeedRange.presets
        }
    }

    private func handleCommandResult(_ result: WatchCommandResult) async {
        isReachable = coordinator.isReachable
        if let snap = result.snapshot {
            applyAuthoritativeSnapshot(snap)
        } else if !result.success {
            pendingTransportState = nil
            pendingTransportStartedAt = nil
            optimisticState = nil
            lastSentSpeed = nil
            lastSentVolume = nil
            reconcileSpeed(from: snapshot.playbackSpeed)
            connectionMessage = result.errorMessage ?? client.connectionErrorMessage
            WatchHaptics.error()
        }
    }

    private func transportStateMatches(
        _ pending: PendingTransportState,
        _ state: WatchPlaybackState
    ) -> Bool {
        switch pending {
        case .playing:
            state == .playing
        case .paused:
            state == .paused || state == .idle
        }
    }

    private func watchState(for pending: PendingTransportState) -> WatchPlaybackState {
        switch pending {
        case .playing: .playing
        case .paused: .paused
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

    private static let pendingTransportTimeout: TimeInterval = 3
    private static let remoteSnapshotSyncInterval: TimeInterval = 30

    private var interpolatedGlobalTime: TimeInterval = 0
    private var interpolatedChapterElapsed: TimeInterval = 0
    private var interpolationAnchorDate: Date?
    private var interpolationAnchorGlobalTime: TimeInterval = 0
    private var interpolationAnchorChapterElapsed: TimeInterval = 0

    private func syncInterpolationAnchors(global: TimeInterval, chapterElapsed: TimeInterval) {
        interpolationAnchorDate = Date()
        interpolationAnchorGlobalTime = global
        interpolationAnchorChapterElapsed = chapterElapsed
        interpolatedGlobalTime = global
        interpolatedChapterElapsed = chapterElapsed
    }

    private func refreshInterpolatedTimesFromWallClock() {
        guard displayState == .playing, let anchor = interpolationAnchorDate else { return }
        let delta = Date().timeIntervalSince(anchor) * Double(snapshot.playbackSpeed)
        interpolatedGlobalTime = min(
            snapshot.globalDuration,
            interpolationAnchorGlobalTime + delta
        )
        if timebarUsesChapterScope {
            interpolatedChapterElapsed = min(
                snapshot.chapterDuration,
                interpolationAnchorChapterElapsed + delta
            )
        }
        playbackTick &+= 1
    }

    private func bumpInterpolatedTimes(by delta: TimeInterval) {
        let newGlobal = max(0, min(snapshot.globalDuration, interpolatedGlobalTime + delta))
        let newChapter: TimeInterval
        if timebarUsesChapterScope {
            newChapter = max(0, min(snapshot.chapterDuration, interpolatedChapterElapsed + delta))
        } else {
            newChapter = interpolatedChapterElapsed
        }
        syncInterpolationAnchors(global: newGlobal, chapterElapsed: newChapter)
        playbackTick &+= 1
    }

    private func restartInterpolationIfNeeded() {
        interpolationCancellable?.cancel()
        interpolationCancellable = nil

        guard displayState == .playing else {
            interpolationAnchorDate = nil
            updateRemoteSyncPolling()
            return
        }

        if interpolationAnchorDate == nil {
            syncInterpolationAnchors(
                global: snapshot.globalCurrentTime,
                chapterElapsed: snapshot.chapterElapsed
            )
        }

        interpolationCancellable = Timer.publish(every: 0.25, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                if self.displayState == .playing {
                    self.refreshInterpolatedTimesFromWallClock()
                } else {
                    self.interpolationAnchorDate = nil
                }
            }
        updateRemoteSyncPolling()
    }

    private func updateRemoteSyncPolling() {
        remoteSyncTask?.cancel()
        remoteSyncTask = nil
        guard snapshot.source == .remote,
              snapshot.bookID != nil,
              displayState == .playing else { return }

        remoteSyncTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.remoteSnapshotSyncInterval))
                guard let self, !Task.isCancelled else { return }
                guard self.snapshot.source == .remote, self.displayState == .playing else { return }
                await self.refresh()
            }
        }
    }
}

//
//  WatchPlayerViewModel.swift
//  AudiopigWatch
//

import Foundation
import UIKit
import Combine

@MainActor
final class WatchPlayerViewModel: ObservableObject {
    @Published private(set) var snapshot: WatchPlaybackSnapshot = .idle
    @Published private(set) var isReachable = false
    @Published private(set) var connectionMessage: String?
    @Published private(set) var chapters: [WatchChapterSummary] = []
    @Published var artworkSkipGesturesEnabled = false
    @Published private(set) var speedPresets: [Float] = WatchSpeedRange.presets
    @Published private(set) var playbackTimelineScope: PlaybackTimelineScope = WatchPlayerViewModel.loadPersistedTimelineScope()

    /// Optimistic transport state for instant button feedback.
    @Published private(set) var optimisticState: WatchPlaybackState?

    @Published var speedDraft: Float = 1.0
    @Published var volumeDraft: Float = 0.5
    @Published var showVolumeOverlay = false

    private let coordinator: any WatchPlaybackCoordinating
    private let client: WatchConnectivityClient
    private var interpolationTimer: Timer?
    private var lastAuthoritativeSnapshot: WatchPlaybackSnapshot = .idle
    private var lastSentSpeed: Float?
    private var lastVolumeSendTime: Date?
    private var pendingVolume: Float?
    private var volumeSendTask: Task<Void, Never>?
    private var volumeOverlayTask: Task<Void, Never>?

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

    var displayState: WatchPlaybackState {
        optimisticState ?? snapshot.playbackState
    }

    var isActive: Bool {
        snapshot.bookID != nil && snapshot.playbackState.isActive
            || snapshot.bookID != nil && displayState.isActive
    }

    var chapterElapsedDisplay: TimeInterval {
        interpolatedElapsed
    }

    var chapterRemainingDisplay: TimeInterval {
        max(0, snapshot.chapterDuration - interpolatedElapsed)
    }

    var chapterProgressDisplay: Double {
        guard snapshot.chapterDuration > 0 else { return 0 }
        return min(1, interpolatedElapsed / snapshot.chapterDuration)
    }

    var timebarElapsedDisplay: TimeInterval {
        switch playbackTimelineScope {
        case .entireBook:
            return interpolatedGlobalTime
        case .currentChapter:
            return interpolatedElapsed
        }
    }

    var timebarRemainingDisplay: TimeInterval {
        switch playbackTimelineScope {
        case .entireBook:
            return max(0, snapshot.globalDuration - interpolatedGlobalTime)
        case .currentChapter:
            return max(0, snapshot.chapterDuration - interpolatedElapsed)
        }
    }

    var timebarProgressDisplay: Double {
        switch playbackTimelineScope {
        case .entireBook:
            guard snapshot.globalDuration > 0 else { return 0 }
            return min(1, interpolatedGlobalTime / snapshot.globalDuration)
        case .currentChapter:
            guard snapshot.chapterDuration > 0 else { return 0 }
            return min(1, interpolatedElapsed / snapshot.chapterDuration)
        }
    }

    var artworkImage: UIImage? {
        guard let data = snapshot.artworkJPEG else { return nil }
        return UIImage(data: data)
    }

    var skipForwardInterval: Int { Int(snapshot.skipForwardSeconds) }
    var skipBackwardInterval: Int { Int(snapshot.skipBackwardSeconds) }

    var speedLabel: String {
        let speed = speedDraft
        return speed.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f×", speed)
            : String(format: "%.2g×", speed)
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
        bumpInterpolatedElapsed(by: snapshot.skipForwardSeconds)
        Task {
            let result = await coordinator.send(.skipForward)
            await handleCommandResult(result)
        }
    }

    func skipBackward() {
        WatchHaptics.directionDown()
        bumpInterpolatedElapsed(by: -snapshot.skipBackwardSeconds)
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

    func applyVolumeDraft() {
        let clamped = max(0, min(1, volumeDraft))
        volumeDraft = clamped
        pendingVolume = clamped
        showVolumeOverlay = true
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

    private func applyAuthoritativeSnapshot(_ incoming: WatchPlaybackSnapshot) {
        if incoming.revision < lastAuthoritativeSnapshot.revision,
           optimisticState != nil {
            // Stale snapshot while optimistic — wait for newer revision.
            return
        }

        lastAuthoritativeSnapshot = incoming
        snapshot = incoming
        optimisticState = nil
        connectionMessage = nil
        interpolatedElapsed = incoming.chapterElapsed
        interpolatedGlobalTime = incoming.globalCurrentTime
        isReachable = coordinator.isReachable

        let phoneSpeed = incoming.playbackSpeed
        if lastSentSpeed == nil || abs(speedDraft - phoneSpeed) > WatchSpeedRange.step {
            speedDraft = phoneSpeed
            lastSentSpeed = phoneSpeed
        }

        volumeDraft = incoming.systemVolume
        restartInterpolationIfNeeded()
    }

    private func applyChapters(_ payload: WatchChaptersPayload) {
        guard payload.bookID == snapshot.bookID || snapshot.bookID == nil else { return }
        chapters = payload.chapters.sorted { $0.orderIndex < $1.orderIndex }
    }

    private func applySettings(_ settings: WatchSettingsSnapshot) {
        artworkSkipGesturesEnabled = settings.artworkSkipGesturesEnabled
        if let incomingPresets = settings.speedPresets, !incomingPresets.isEmpty {
            speedPresets = incomingPresets.sorted()
        } else {
            speedPresets = WatchSpeedRange.presets
        }
        if let scope = settings.playbackTimelineScope {
            playbackTimelineScope = scope
            Self.persistTimelineScope(scope)
        }
    }

    private func handleCommandResult(_ result: WatchCommandResult) async {
        isReachable = coordinator.isReachable
        if let snap = result.snapshot {
            applyAuthoritativeSnapshot(snap)
        } else if !result.success {
            optimisticState = nil
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
        let result = await coordinator.send(.setVolume(volume))
        await handleCommandResult(result)
    }

    private static func normalizedSpeed(_ speed: Float) -> Float {
        let stepped = (speed / WatchSpeedRange.step).rounded() * WatchSpeedRange.step
        return min(WatchSpeedRange.max, max(WatchSpeedRange.min, stepped))
    }

    // MARK: - Local interpolation

    private var interpolatedElapsed: TimeInterval = 0
    private var interpolatedGlobalTime: TimeInterval = 0

    private func bumpInterpolatedElapsed(by delta: TimeInterval) {
        interpolatedElapsed = max(0, min(snapshot.chapterDuration, interpolatedElapsed + delta))
    }

    private func bumpInterpolatedGlobal(by delta: TimeInterval) {
        interpolatedGlobalTime = max(0, min(snapshot.globalDuration, interpolatedGlobalTime + delta))
    }

    private func restartInterpolationIfNeeded() {
        interpolationTimer?.invalidate()
        interpolationTimer = nil
        guard snapshot.playbackState == .playing else { return }
        interpolationTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.snapshot.playbackState == .playing else { return }
                let delta = 0.25 * Double(self.snapshot.playbackSpeed)
                self.bumpInterpolatedElapsed(by: delta)
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

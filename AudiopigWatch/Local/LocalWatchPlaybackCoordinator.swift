//
//  LocalWatchPlaybackCoordinator.swift
//  AudiopigWatch
//

import Foundation

@MainActor
final class LocalWatchPlaybackCoordinator: WatchPlaybackCoordinating {
    private let store: any WatchLocalLibraryStoring
    private let engine: WatchAudioEngine
    private let client: WatchConnectivityClient

    private var snapshotHandler: ((WatchPlaybackSnapshot) -> Void)?
    private var chaptersHandler: ((WatchChaptersPayload) -> Void)?
    private var currentManifest: WatchTransferManifest?
    private var chapters: [WatchChapterSummary] = []
    private var chapterTimings: [WatchChapterTiming] = []
    private var revision: UInt64 = 0
    private var skipForwardSeconds: TimeInterval = 15
    private var skipBackwardSeconds: TimeInterval = 15
    private var defaultSpeed: Float = 1.0
    private var universalSpeedEnabled: Bool = false
    private var universalSpeedValue: Float = 1.0
    private var positionSyncTask: Task<Void, Never>?
    private var resumePersistTask: Task<Void, Never>?
    private var lastSyncedPosition: TimeInterval = -1
    private var lastPublishTime = Date.distantPast
    private var pendingResumeTime: TimeInterval?

    private(set) var snapshot: WatchPlaybackSnapshot?

    var isReachable: Bool { true }

    init(store: any WatchLocalLibraryStoring, engine: WatchAudioEngine, client: WatchConnectivityClient) {
        self.store = store
        self.engine = engine
        self.client = client

        if let settings = client.latestSettings {
            skipForwardSeconds = settings.skipForwardSeconds
            skipBackwardSeconds = settings.skipBackwardSeconds
            defaultSpeed = settings.defaultSpeed ?? defaultSpeed
            universalSpeedEnabled = settings.universalPlaybackSpeedEnabled ?? false
            universalSpeedValue = settings.universalPlaybackSpeed ?? universalSpeedValue
        }

        engine.onTimeUpdate = { [weak self] _ in
            self?.publishSnapshot(immediate: false)
        }
        engine.onStateChange = { [weak self] state in
            self?.publishSnapshot(immediate: true)
            if state == .playing {
                self?.startPositionSync()
            } else {
                self?.stopPositionSync(flush: true)
            }
        }

        client.setSettingsHandler { [weak self] settings in
            self?.skipForwardSeconds = settings.skipForwardSeconds
            self?.skipBackwardSeconds = settings.skipBackwardSeconds
            self?.defaultSpeed = settings.defaultSpeed ?? self?.defaultSpeed ?? 1.0
            self?.universalSpeedEnabled = settings.universalPlaybackSpeedEnabled ?? false
            if let uni = settings.universalPlaybackSpeed {
                self?.universalSpeedValue = uni
            }
        }
    }

    func setSnapshotHandler(_ handler: @escaping (WatchPlaybackSnapshot) -> Void) {
        snapshotHandler = handler
        if let snapshot {
            handler(snapshot)
        }
    }

    func setChaptersHandler(_ handler: @escaping (WatchChaptersPayload) -> Void) {
        chaptersHandler = handler
        if let manifest = currentManifest {
            handler(WatchChaptersPayload(bookID: manifest.bookID, chapters: chapters))
        }
    }

    func send(_ command: WatchCommand) async -> WatchCommandResult {
        switch command {
        case .loadLocalBook(let bookID, let autoPlay):
            return await loadBook(bookID: bookID, autoPlay: autoPlay)

        case .requestLocalBooks:
            return .ok()

        case .togglePlayPause:
            engine.togglePlayPause()
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .play:
            engine.play()
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .pause:
            engine.pause()
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .skipForward:
            await engine.skip(by: skipForwardSeconds)
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .skipBackward:
            await engine.skip(by: -skipBackwardSeconds)
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .setSpeed(let speed):
            engine.setSpeed(speed)
            if universalSpeedEnabled {
                universalSpeedValue = speed
            } else if let bookID = currentManifest?.bookID {
                persistPerBookSpeed(bookID: bookID, speed: speed)
            }
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .setVolume(let volume):
            engine.setVolume(volume)
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .seekToChapterIndex(let index):
            guard chapters.indices.contains(index) else {
                return .failure("Chapter not found.")
            }
            await engine.seek(to: chapters[index].startTime, autoPlay: engine.playbackState == .playing)
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .seekToChapter(let id):
            guard let chapter = chapters.first(where: { $0.id == id }) else {
                return .failure("Chapter not found.")
            }
            await engine.seek(to: chapter.startTime, autoPlay: engine.playbackState == .playing)
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .requestSnapshot:
            publishSnapshot(immediate: true)
            return .ok(snapshot: snapshot)

        case .deleteLocalBook(let bookID):
            if currentManifest?.bookID == bookID {
                stopPlayback()
            }
            try? store.remove(bookID: bookID)
            return .ok()

        default:
            return .failure("Command not supported for local playback.")
        }
    }

    func unloadIfPlaying(bookID: UUID) {
        guard currentManifest?.bookID == bookID else { return }
        stopPlayback()
    }

    func stopPlaybackIfActive() {
        guard currentManifest != nil else { return }
        stopPlayback()
    }

    // MARK: - Private

    private func loadBook(bookID: UUID, autoPlay: Bool) async -> WatchCommandResult {
        guard let manifest = store.manifest(for: bookID),
              let url = store.localURL(for: bookID) else {
            return .failure("Book not found on Watch.")
        }

        currentManifest = manifest
        chapters = manifest.chapters.sorted { $0.orderIndex < $1.orderIndex }
        chapterTimings = chapters.map { WatchChapterTiming(startTime: $0.startTime, duration: $0.duration) }
        chaptersHandler?(WatchChaptersPayload(bookID: bookID, chapters: chapters))

        try? store.updateLastPlayed(bookID: bookID)
        engine.load(
            url: url,
            bookID: bookID,
            startTime: manifest.resumePosition,
            duration: manifest.duration,
            autoPlay: autoPlay
        )
        let desiredSpeed: Float
        if universalSpeedEnabled {
            desiredSpeed = universalSpeedValue
        } else if let saved = loadPerBookSpeed(bookID: bookID) {
            desiredSpeed = saved
        } else {
            desiredSpeed = defaultSpeed
            persistPerBookSpeed(bookID: bookID, speed: desiredSpeed)
        }
        engine.setSpeed(desiredSpeed)
        publishSnapshot(immediate: true, includeArtwork: true)
        if autoPlay {
            startPositionSync()
        }
        return .ok(snapshot: snapshot)
    }

    private func perBookSpeedDefaultsKey(_ bookID: UUID) -> String {
        "watch.bookPlaybackSpeed.\(bookID.uuidString)"
    }

    private func loadPerBookSpeed(bookID: UUID) -> Float? {
        let key = perBookSpeedDefaultsKey(bookID)
        let stored = UserDefaults.standard.float(forKey: key)
        return stored > 0 ? stored : nil
    }

    private func persistPerBookSpeed(bookID: UUID, speed: Float) {
        let key = perBookSpeedDefaultsKey(bookID)
        UserDefaults.standard.set(speed, forKey: key)
    }

    private func stopPlayback() {
        stopPositionSync(flush: true)
        engine.unload()
        currentManifest = nil
        chapters = []
        chapterTimings = []
        let idle = WatchPlaybackSnapshot.idle
        snapshot = idle
        snapshotHandler?(idle)
    }

    private func publishSnapshot(immediate: Bool, includeArtwork: Bool = false) {
        guard let manifest = currentManifest else { return }

        let now = Date()
        if !immediate, now.timeIntervalSince(lastPublishTime) < 1.0 { return }
        lastPublishTime = now

        revision += 1
        let progress = ChapterProgressCalculator.progress(globalTime: engine.currentTime, chapters: chapterTimings)

        let chapterTitle: String
        if chapters.count > 1, chapters.indices.contains(progress.chapterIndex) {
            chapterTitle = chapters[progress.chapterIndex].title
        } else {
            chapterTitle = manifest.title
        }

        let artwork: Data? = includeArtwork ? manifest.thumbnailJPEG : snapshot?.artworkJPEG

        let snap = WatchPlaybackSnapshot(
            revision: revision,
            bookID: manifest.bookID,
            title: manifest.title,
            author: manifest.author,
            chapterTitle: chapterTitle,
            playbackState: engine.playbackState,
            playbackSpeed: engine.playbackSpeed,
            skipForwardSeconds: skipForwardSeconds,
            skipBackwardSeconds: skipBackwardSeconds,
            chapterIndex: progress.chapterIndex,
            chapterCount: chapters.count,
            chapterElapsed: progress.chapterElapsed,
            chapterDuration: progress.chapterDuration,
            chapterProgress: progress.chapterProgress,
            globalCurrentTime: engine.currentTime,
            globalDuration: manifest.duration,
            systemVolume: engine.systemVolume,
            source: .local,
            artworkJPEG: artwork
        )
        snapshot = snap
        snapshotHandler?(snap)

        if immediate {
            scheduleResumePersist(engine.currentTime, flush: true)
        } else {
            scheduleResumePersist(engine.currentTime, flush: false)
        }
    }

    private func startPositionSync() {
        guard positionSyncTask == nil else { return }
        positionSyncTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled,
                      engine.playbackState == .playing,
                      let bookID = currentManifest?.bookID else { return }
                flushResumeToDisk()
                guard client.isReachable else { continue }
                _ = await client.send(.syncLocalPlaybackPosition(bookID: bookID, time: engine.currentTime))
            }
        }
    }

    private func stopPositionSync(flush: Bool) {
        positionSyncTask?.cancel()
        positionSyncTask = nil
        if flush {
            flushResumeToDisk()
        }
    }

    private func scheduleResumePersist(_ time: TimeInterval, flush: Bool) {
        pendingResumeTime = time
        guard abs(time - lastSyncedPosition) > 1 else { return }

        if flush {
            flushResumeToDisk()
            return
        }

        resumePersistTask?.cancel()
        resumePersistTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            flushResumeToDisk()
        }
    }

    private func flushResumeToDisk() {
        guard let bookID = currentManifest?.bookID else { return }
        let time = pendingResumeTime ?? engine.currentTime
        guard abs(time - lastSyncedPosition) > 1 else { return }
        lastSyncedPosition = time
        try? store.updateResumePosition(bookID: bookID, time: time)
    }
}

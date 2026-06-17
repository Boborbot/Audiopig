//
//  WatchSnapshotBuilder.swift
//  Audiopig
//

import AVFoundation
import UIKit

enum WatchSnapshotBuilder {
    static func makeSnapshot(
        revision: UInt64,
        audiobook: Audiobook?,
        chapters: [Chapter],
        currentChapterIndex: Int,
        playbackState: PlaybackState,
        playbackSpeed: Float,
        skipForwardSeconds: TimeInterval,
        skipBackwardSeconds: TimeInterval,
        globalTime: TimeInterval,
        globalDuration: TimeInterval,
        coverImage: UIImage?,
        includeArtwork: Bool
    ) -> WatchPlaybackSnapshot {
        let timings = chapters
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { WatchChapterTiming(startTime: $0.startTime, duration: $0.duration) }

        let progress = ChapterProgressCalculator.progress(globalTime: globalTime, chapters: timings)

        let chapterTitle: String
        if chapters.count > 1, chapters.indices.contains(progress.chapterIndex) {
            chapterTitle = chapters[progress.chapterIndex].title
        } else {
            chapterTitle = audiobook?.title ?? ""
        }

        let watchState = mapPlaybackState(playbackState)
        let volume = AVAudioSession.sharedInstance().outputVolume

        let artwork: Data?
        if includeArtwork, let coverImage {
            artwork = ThumbnailEncoder.jpegData(from: coverImage, size: .player)
        } else {
            artwork = nil
        }

        return WatchPlaybackSnapshot(
            revision: revision,
            bookID: audiobook?.id,
            title: audiobook?.title ?? "",
            author: audiobook?.author ?? "",
            chapterTitle: chapterTitle,
            playbackState: watchState,
            playbackSpeed: playbackSpeed,
            skipForwardSeconds: skipForwardSeconds,
            skipBackwardSeconds: skipBackwardSeconds,
            chapterIndex: progress.chapterIndex,
            chapterCount: chapters.count,
            chapterElapsed: progress.chapterElapsed,
            chapterDuration: progress.chapterDuration,
            chapterProgress: progress.chapterProgress,
            globalCurrentTime: globalTime,
            globalDuration: globalDuration,
            systemVolume: volume,
            source: .remote,
            artworkJPEG: artwork
        )
    }

    static func mapPlaybackState(_ state: PlaybackState) -> WatchPlaybackState {
        switch state {
        case .idle: return .idle
        case .loading: return .loading
        case .playing: return .playing
        case .paused: return .paused
        case .finished: return .finished
        case .failed(let message): return .failed(message: message)
        }
    }

    static func makeChaptersPayload(bookID: UUID, chapters: [Chapter]) -> WatchChaptersPayload {
        let summaries = chapters
            .sorted { $0.orderIndex < $1.orderIndex }
            .map {
                WatchChapterSummary(
                    id: $0.id,
                    title: $0.title,
                    startTime: $0.startTime,
                    duration: $0.duration,
                    orderIndex: $0.orderIndex
                )
            }
        return WatchChaptersPayload(bookID: bookID, chapters: summaries)
    }

    static func makeBookSummary(from audiobook: Audiobook, coverImage: UIImage?) -> WatchBookSummary {
        WatchBookSummary(
            id: audiobook.id,
            title: audiobook.title,
            author: audiobook.author,
            duration: audiobook.duration,
            currentPlaybackTime: audiobook.currentPlaybackTime,
            lastPlayedAt: audiobook.lastPlayedAt,
            thumbnailJPEG: coverImage.flatMap { ThumbnailEncoder.jpegData(from: $0, size: .list) }
        )
    }
}

//
//  WidgetPlaybackService.swift
//  Audiopig
//
//  Handles lock screen widget / control playback intents.
//

import Foundation
import SwiftData

@MainActor
enum WidgetPlaybackService {

    private static var libraryViewModel: LibraryViewModel?

    static func bind(libraryViewModel: LibraryViewModel) {
        self.libraryViewModel = libraryViewModel
        WidgetPlaybackLauncher.playLastAudiobook = {
            try await playLastAudiobook()
        }
    }

    static func playLastAudiobook() async throws {
        if let libraryViewModel {
            try await libraryViewModel.playLastAudiobookFromWidget()
        } else {
            try await playLastAudiobookDirect()
        }
        WidgetPlaybackPresentation.requestPlayerPresentation()
    }

    private static func playLastAudiobookDirect() async throws {
        let container = DependencyContainer.requireShared()
        let snapshot = WidgetListeningSnapshot.load()
        guard let idString = snapshot.lastPlayedAudiobookID,
              let bookID = UUID(uuidString: idString) else {
            throw WidgetPlaybackError.noLastPlayedBook
        }

        let context = container.modelContainer.mainContext
        var descriptor = FetchDescriptor<Audiobook>(
            predicate: #Predicate { $0.id == bookID }
        )
        descriptor.fetchLimit = 1
        guard let audiobook = try? context.fetch(descriptor).first else {
            throw WidgetPlaybackError.bookNotFound
        }

        try? container.libraryManager.repairAudiobookFileReferences(in: context)

        if container.audioEngine.loadedAudiobookID == bookID {
            switch container.audioEngine.playbackState {
            case .playing:
                return
            case .paused, .finished, .idle:
                try container.audioEngine.play()
                WidgetSnapshotWriter.updateLastPlayed(
                    title: audiobook.title,
                    author: audiobook.author,
                    audiobookID: audiobook.id,
                    progress: WidgetListeningSnapshot.playbackProgress(
                        currentTime: audiobook.currentPlaybackTime,
                        duration: audiobook.duration
                    )
                )
                return
            case .loading, .failed:
                break
            }
        }

        try await container.audioEngine.load(audiobook: audiobook)
        try container.audioEngine.play()
        audiobook.lastPlayedAt = .now
        try? context.save()
        WidgetSnapshotWriter.updateLastPlayed(
            title: audiobook.title,
            author: audiobook.author,
            audiobookID: audiobook.id,
            progress: WidgetListeningSnapshot.playbackProgress(
                currentTime: audiobook.currentPlaybackTime,
                duration: audiobook.duration
            )
        )
    }
}

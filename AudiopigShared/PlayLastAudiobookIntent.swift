//
//  PlayLastAudiobookIntent.swift
//  AudiopigShared
//
//  Lock screen widget/control action — resumes the last audiobook and opens the player.
//

import AppIntents
import Foundation

public enum WidgetPlaybackError: Error, CustomLocalizedStringResourceConvertible {
    case notReady
    case noLastPlayedBook
    case bookNotFound

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .notReady:
            "Audiopig is not ready to play yet."
        case .noLastPlayedBook:
            "No recent audiobook to resume."
        case .bookNotFound:
            "That audiobook is no longer in your library."
        }
    }
}

/// Host app registers this before the widget intent can start playback.
public enum WidgetPlaybackLauncher {
    @MainActor
    public static var playLastAudiobook: (() async throws -> Void)?
}

public struct PlayLastAudiobookIntent: AppIntent, AudioPlaybackIntent {
    public static var title: LocalizedStringResource = "Continue Listening"
    public static var description = IntentDescription("Resume your last audiobook.")
    public static var openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        guard let playLastAudiobook = WidgetPlaybackLauncher.playLastAudiobook else {
            throw WidgetPlaybackError.notReady
        }
        try await playLastAudiobook()
        return .result()
    }
}

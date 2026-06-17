//
//  WatchCommand.swift
//  AudiopigShared
//

import Foundation

public enum WatchCommand: Codable, Sendable, Equatable {
    case requestRecentBooks
    case requestLocalBooks
    case requestSnapshot
    case loadBook(bookID: UUID, autoPlay: Bool)
    case loadLocalBook(bookID: UUID, autoPlay: Bool)
    case togglePlayPause
    case play
    case pause
    case skipForward
    case skipBackward
    case setSpeed(Float)
    case setVolume(Float)
    case seekToChapterIndex(Int)
    case seekToChapter(id: UUID)
    case setArtworkSkipGesturesEnabled(Bool)
    case analyzeLulls
    case seekToLull(endTime: TimeInterval)
    case deleteLocalBook(bookID: UUID)
    case syncLocalPlaybackPosition(bookID: UUID, time: TimeInterval)
    case acknowledgeLocalBooks(WatchLocalBooksPayload)
    case reportTransferIngestFailed(bookID: UUID, errorMessage: String)

    private enum CodingKeys: String, CodingKey {
        case kind
        case bookID
        case autoPlay
        case speed
        case volume
        case chapterIndex
        case chapterID
        case enabled
        case time
        case localBooks
        case errorMessage
    }

    private enum Kind: String, Codable {
        case requestRecentBooks
        case requestLocalBooks
        case requestSnapshot
        case loadBook
        case loadLocalBook
        case togglePlayPause
        case play
        case pause
        case skipForward
        case skipBackward
        case setSpeed
        case setVolume
        case seekToChapterIndex
        case seekToChapter
        case setArtworkSkipGesturesEnabled
        case analyzeLulls
        case seekToLull
        case deleteLocalBook
        case syncLocalPlaybackPosition
        case acknowledgeLocalBooks
        case reportTransferIngestFailed
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .requestRecentBooks: self = .requestRecentBooks
        case .requestLocalBooks: self = .requestLocalBooks
        case .requestSnapshot: self = .requestSnapshot
        case .loadBook:
            let id = try container.decode(UUID.self, forKey: .bookID)
            let autoPlay = try container.decode(Bool.self, forKey: .autoPlay)
            self = .loadBook(bookID: id, autoPlay: autoPlay)
        case .loadLocalBook:
            let id = try container.decode(UUID.self, forKey: .bookID)
            let autoPlay = try container.decode(Bool.self, forKey: .autoPlay)
            self = .loadLocalBook(bookID: id, autoPlay: autoPlay)
        case .togglePlayPause: self = .togglePlayPause
        case .play: self = .play
        case .pause: self = .pause
        case .skipForward: self = .skipForward
        case .skipBackward: self = .skipBackward
        case .setSpeed:
            self = .setSpeed(try container.decode(Float.self, forKey: .speed))
        case .setVolume:
            self = .setVolume(try container.decode(Float.self, forKey: .volume))
        case .seekToChapterIndex:
            self = .seekToChapterIndex(try container.decode(Int.self, forKey: .chapterIndex))
        case .seekToChapter:
            self = .seekToChapter(id: try container.decode(UUID.self, forKey: .chapterID))
        case .setArtworkSkipGesturesEnabled:
            self = .setArtworkSkipGesturesEnabled(try container.decode(Bool.self, forKey: .enabled))
        case .analyzeLulls:
            self = .analyzeLulls
        case .seekToLull:
            self = .seekToLull(endTime: try container.decode(TimeInterval.self, forKey: .time))
        case .deleteLocalBook:
            self = .deleteLocalBook(bookID: try container.decode(UUID.self, forKey: .bookID))
        case .syncLocalPlaybackPosition:
            let id = try container.decode(UUID.self, forKey: .bookID)
            let time = try container.decode(TimeInterval.self, forKey: .time)
            self = .syncLocalPlaybackPosition(bookID: id, time: time)
        case .acknowledgeLocalBooks:
            self = .acknowledgeLocalBooks(try container.decode(WatchLocalBooksPayload.self, forKey: .localBooks))
        case .reportTransferIngestFailed:
            let id = try container.decode(UUID.self, forKey: .bookID)
            let message = try container.decode(String.self, forKey: .errorMessage)
            self = .reportTransferIngestFailed(bookID: id, errorMessage: message)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .requestRecentBooks:
            try container.encode(Kind.requestRecentBooks, forKey: .kind)
        case .requestLocalBooks:
            try container.encode(Kind.requestLocalBooks, forKey: .kind)
        case .requestSnapshot:
            try container.encode(Kind.requestSnapshot, forKey: .kind)
        case .loadBook(let bookID, let autoPlay):
            try container.encode(Kind.loadBook, forKey: .kind)
            try container.encode(bookID, forKey: .bookID)
            try container.encode(autoPlay, forKey: .autoPlay)
        case .loadLocalBook(let bookID, let autoPlay):
            try container.encode(Kind.loadLocalBook, forKey: .kind)
            try container.encode(bookID, forKey: .bookID)
            try container.encode(autoPlay, forKey: .autoPlay)
        case .togglePlayPause:
            try container.encode(Kind.togglePlayPause, forKey: .kind)
        case .play:
            try container.encode(Kind.play, forKey: .kind)
        case .pause:
            try container.encode(Kind.pause, forKey: .kind)
        case .skipForward:
            try container.encode(Kind.skipForward, forKey: .kind)
        case .skipBackward:
            try container.encode(Kind.skipBackward, forKey: .kind)
        case .setSpeed(let speed):
            try container.encode(Kind.setSpeed, forKey: .kind)
            try container.encode(speed, forKey: .speed)
        case .setVolume(let volume):
            try container.encode(Kind.setVolume, forKey: .kind)
            try container.encode(volume, forKey: .volume)
        case .seekToChapterIndex(let index):
            try container.encode(Kind.seekToChapterIndex, forKey: .kind)
            try container.encode(index, forKey: .chapterIndex)
        case .seekToChapter(let id):
            try container.encode(Kind.seekToChapter, forKey: .kind)
            try container.encode(id, forKey: .chapterID)
        case .setArtworkSkipGesturesEnabled(let enabled):
            try container.encode(Kind.setArtworkSkipGesturesEnabled, forKey: .kind)
            try container.encode(enabled, forKey: .enabled)
        case .analyzeLulls:
            try container.encode(Kind.analyzeLulls, forKey: .kind)
        case .seekToLull(let endTime):
            try container.encode(Kind.seekToLull, forKey: .kind)
            try container.encode(endTime, forKey: .time)
        case .deleteLocalBook(let bookID):
            try container.encode(Kind.deleteLocalBook, forKey: .kind)
            try container.encode(bookID, forKey: .bookID)
        case .syncLocalPlaybackPosition(let bookID, let time):
            try container.encode(Kind.syncLocalPlaybackPosition, forKey: .kind)
            try container.encode(bookID, forKey: .bookID)
            try container.encode(time, forKey: .time)
        case .acknowledgeLocalBooks(let payload):
            try container.encode(Kind.acknowledgeLocalBooks, forKey: .kind)
            try container.encode(payload, forKey: .localBooks)
        case .reportTransferIngestFailed(let bookID, let errorMessage):
            try container.encode(Kind.reportTransferIngestFailed, forKey: .kind)
            try container.encode(bookID, forKey: .bookID)
            try container.encode(errorMessage, forKey: .errorMessage)
        }
    }
}

public struct WatchCommandResult: Codable, Sendable, Equatable {
    public let success: Bool
    public let errorMessage: String?
    public let snapshot: WatchPlaybackSnapshot?
    public let lullResult: WatchLullResult?
    public let localBooks: WatchLocalBooksPayload?

    public init(
        success: Bool,
        errorMessage: String? = nil,
        snapshot: WatchPlaybackSnapshot? = nil,
        lullResult: WatchLullResult? = nil,
        localBooks: WatchLocalBooksPayload? = nil
    ) {
        self.success = success
        self.errorMessage = errorMessage
        self.snapshot = snapshot
        self.lullResult = lullResult
        self.localBooks = localBooks
    }

    public static func ok(
        snapshot: WatchPlaybackSnapshot? = nil,
        lullResult: WatchLullResult? = nil,
        localBooks: WatchLocalBooksPayload? = nil
    ) -> WatchCommandResult {
        WatchCommandResult(success: true, snapshot: snapshot, lullResult: lullResult, localBooks: localBooks)
    }

    public static func failure(_ message: String) -> WatchCommandResult {
        WatchCommandResult(success: false, errorMessage: message)
    }
}

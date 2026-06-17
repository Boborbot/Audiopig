//
//  WatchMessageKeys.swift
//  AudiopigShared
//

import Foundation

public enum WatchMessageKeys {
    public static let snapshot = "watch.snapshot"
    public static let chapters = "watch.chapters"
    public static let recentBooks = "watch.recentBooks"
    public static let localBooks = "watch.localBooks"
    public static let settings = "watch.settings"
    public static let command = "watch.command"
    public static let commandResult = "watch.commandResult"

    /// Metadata key on `WCSession.transferFile` payloads.
    public static let transferManifest = "watch.transferManifest"
    public static let transferBookID = "watch.transferBookID"
}

public enum WatchMessageCodec {
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        try JSONDecoder().decode(type, from: data)
    }

    public static func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let data = try encode(value)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.coderInvalidValue)
        }
        return string
    }

    public static func decodeFromString<T: Decodable>(_ type: T.Type, _ string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw CocoaError(.coderReadCorrupt)
        }
        return try decode(type, from: data)
    }
}

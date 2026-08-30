//
//  WatchApplicationContextBudget.swift
//  AudiopigShared
//

import Foundation

/// WatchConnectivity payload size limits (Apple documents ~65 KB for messages, ~262 KB for application context).
public enum WatchApplicationContextBudget {
    /// Conservative cap for `updateApplicationContext` payloads.
    public static let contextMaxBytes = 200_000
    /// Conservative cap for `sendMessage` reply payloads.
    public static let messageMaxBytes = 60_000

    public static func encodedByteCount<T: Encodable>(_ value: T) -> Int {
        (try? WatchMessageCodec.encode(value))?.count ?? Int.max
    }
}

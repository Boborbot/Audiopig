//
//  WatchLocalBooksCache.swift
//  AudiopigShared
//

import Foundation

/// Last-known Watch library snapshot on iPhone (survives restarts when WCSession sync is slow).
public enum WatchLocalBooksCache {
    private static let defaultsKey = "watch.localBooks.snapshot"

    public static func save(_ payload: WatchLocalBooksPayload) {
        guard let data = try? WatchMessageCodec.encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    public static func load() -> WatchLocalBooksPayload? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? WatchMessageCodec.decode(WatchLocalBooksPayload.self, from: data)
    }

    public static func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }
}

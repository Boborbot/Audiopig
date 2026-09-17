//
//  WatchConnectivityDiagnostics.swift
//  AudiopigShared
//

import Foundation
import os

enum WatchConnectivityDiagnostics {
    /// Bump when changing Watch sync behavior so device logs prove the new build is running.
    nonisolated static let buildTag = "Audiopig-Watch-1.1.3"

    private nonisolated static let logger = Logger(
        subsystem: "com.nitay.Audiopig",
        category: "WatchConnectivity"
    )

    nonisolated static func info(_ message: String) {
        logger.info("\(Self.buildTag, privacy: .public): \(message, privacy: .public)")
    }
}

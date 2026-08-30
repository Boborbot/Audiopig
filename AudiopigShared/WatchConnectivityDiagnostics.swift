//
//  WatchConnectivityDiagnostics.swift
//  AudiopigShared
//

import Foundation
import os

enum WatchConnectivityDiagnostics {
    /// Bump when changing Watch sync behavior so device logs prove the new build is running.
    static let buildTag = "Audiopig-WC-v4-transfer-loadBook"

    private static let logger = Logger(
        subsystem: "com.nitay.Audiopig",
        category: "WatchConnectivity"
    )

    static func info(_ message: String) {
        logger.info("\(Self.buildTag, privacy: .public): \(message, privacy: .public)")
    }
}

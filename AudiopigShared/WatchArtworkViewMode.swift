//
//  WatchArtworkViewMode.swift
//  AudiopigShared
//

import Foundation

/// How the Watch player shows a dedicated artwork + transport screen (AudioPig Plus).
public enum WatchArtworkViewMode: String, Codable, Sendable, CaseIterable, Equatable {
    case off
    case replaceStandardControls
    case add

    public var label: String {
        switch self {
        case .off:
            "Off"
        case .replaceStandardControls:
            "Replace Standard Controls"
        case .add:
            "Add"
        }
    }

    public var watchSettingsLabel: String {
        switch self {
        case .off:
            "Off"
        case .replaceStandardControls:
            "Replace Controls"
        case .add:
            "Add"
        }
    }
}

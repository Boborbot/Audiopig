//
//  PlaybackState.swift
//  Audiopig
//

import Foundation

enum PlaybackState: Equatable, Sendable {
    case idle
    case loading
    case playing
    case paused
    case finished
    case failed(message: String)
}

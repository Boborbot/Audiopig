//
//  WidgetPlaybackPresentation.swift
//  Audiopig
//
//  Presents the player sheet after lock screen widget / control playback.
//

import Foundation

@MainActor
enum WidgetPlaybackPresentation {

    private static var presentPlayer: (() -> Void)?
    private static var pendingPresentation = false

    static func install(presentPlayer: @escaping () -> Void) {
        self.presentPlayer = presentPlayer
        if pendingPresentation {
            pendingPresentation = false
            presentPlayer()
        }
    }

    static func requestPlayerPresentation() {
        if let presentPlayer {
            presentPlayer()
        } else {
            pendingPresentation = true
        }
    }
}

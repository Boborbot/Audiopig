//
//  WatchHaptics.swift
//  AudiopigWatch
//
//  Real Watch: Taptic Engine (wrist taps, not speaker).
//  Simulator: Mac plays click sounds as a stand-in for the same haptic types.
//

import WatchKit

enum WatchHaptics {
    /// watchOS exposes fixed haptic types only — step down one notch to approximate half strength.
    private static func playSoftened(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(softened(type))
    }

    private static func softened(_ type: WKHapticType) -> WKHapticType {
        switch type {
        case .start, .notification: .directionUp
        case .stop: .directionDown
        case .directionUp, .directionDown: .click
        default: type
        }
    }

    static func click() {
        WKInterfaceDevice.current().play(.click)
    }

    static func play() {
        playSoftened(.start)
    }

    static func pause() {
        playSoftened(.stop)
    }

    static func error() {
        playSoftened(.notification)
    }

    static func directionUp() {
        playSoftened(.directionUp)
    }

    static func directionDown() {
        playSoftened(.directionDown)
    }
}

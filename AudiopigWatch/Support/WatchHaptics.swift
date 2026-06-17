//
//  WatchHaptics.swift
//  AudiopigWatch
//
//  Real Watch: Taptic Engine (wrist taps, not speaker).
//  Simulator: Mac plays click sounds as a stand-in for the same haptic types.
//

import WatchKit

enum WatchHaptics {
    static func click() {
        WKInterfaceDevice.current().play(.click)
    }

    static func play() {
        WKInterfaceDevice.current().play(.start)
    }

    static func pause() {
        WKInterfaceDevice.current().play(.stop)
    }

    static func error() {
        WKInterfaceDevice.current().play(.notification)
    }

    static func directionUp() {
        WKInterfaceDevice.current().play(.directionUp)
    }

    static func directionDown() {
        WKInterfaceDevice.current().play(.directionDown)
    }
}

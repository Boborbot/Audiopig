//
//  WatchDesignSystem.swift
//  AudiopigWatch
//

import SwiftUI

enum WDS {
    enum Color {
        static let coral = SwiftUI.Color(red: 0xF1 / 255, green: 0x84 / 255, blue: 0x70 / 255)
        static let placeholder = SwiftUI.Color.gray.opacity(0.35)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
    }

    enum Typography {
        static let title = Font.headline
        static let chapter = Font.caption
        static let time = Font.caption2.monospacedDigit()
    }
}

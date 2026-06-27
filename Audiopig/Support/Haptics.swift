//
//  Haptics.swift
//  Audiopig
//

import UIKit

enum Haptics {

    /// Light tactile for menus, toggles, and secondary confirmations.
    static func subtle() {
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.prepare()
        generator.impactOccurred(intensity: 0.7)
    }
}

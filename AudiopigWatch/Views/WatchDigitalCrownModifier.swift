//
//  WatchDigitalCrownModifier.swift
//  AudiopigWatch
//

import SwiftUI

extension View {
    /// Mounts one valid Digital Crown handler for the active player page.
    @ViewBuilder
    func watchDigitalCrownLow<V>(
        isActive: Bool,
        value: Binding<V>,
        from: V,
        through: V,
        by: V.Stride? = nil,
        isContinuous: Bool = false,
        isHapticFeedbackEnabled: Bool = false
    ) -> some View where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
        if isActive, from <= through, by.map({ $0 > 0 }) ?? true {
            digitalCrownRotation(
                value,
                from: from,
                through: through,
                by: by,
                sensitivity: .low,
                isContinuous: isContinuous,
                isHapticFeedbackEnabled: isHapticFeedbackEnabled
            )
        } else {
            self
        }
    }
}

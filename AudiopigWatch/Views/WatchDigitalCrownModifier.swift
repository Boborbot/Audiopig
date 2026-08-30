//
//  WatchDigitalCrownModifier.swift
//  AudiopigWatch
//

import SwiftUI

extension View {
    /// Applies Digital Crown rotation only while the page is active.
    /// watchOS crashes when multiple crown handlers exist in a vertical `TabView`.
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
        if isActive {
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

    @ViewBuilder
    func watchDigitalCrownMedium<V>(
        isActive: Bool,
        value: Binding<V>,
        from: V,
        through: V,
        by: V.Stride? = nil,
        isContinuous: Bool = false,
        isHapticFeedbackEnabled: Bool = false
    ) -> some View where V: BinaryFloatingPoint, V.Stride: BinaryFloatingPoint {
        if isActive {
            digitalCrownRotation(
                value,
                from: from,
                through: through,
                by: by,
                sensitivity: .medium,
                isContinuous: isContinuous,
                isHapticFeedbackEnabled: isHapticFeedbackEnabled
            )
        } else {
            self
        }
    }
}

//
//  CircularProgressView.swift
//  Audiopig
//

import SwiftUI

/// Salmon donut-band progress: a neutral track ring with a coral band that fills
/// clockwise from 12 o'clock. At 100% the band is a complete ring.
struct CircularProgressView: View {
    let progress: Double // 0…1

    private static let donutFill = FillStyle(eoFill: true, antialiased: true)

    var body: some View {
        ZStack {
            DonutBandShape(progress: 1)
                .fill(DS.Color.tertiary.opacity(0.25), style: Self.donutFill)

            DonutBandShape(progress: progress)
                .fill(DS.Color.coral, style: Self.donutFill)
        }
    }
}

// MARK: - Donut Band Shape

/// Annular band from 12 o'clock clockwise. `progress == 1` draws a full ring.
private struct DonutBandShape: Shape {
    var progress: Double

    /// Band width as a fraction of the view diameter (5 pt in a 36 pt frame).
    private static let bandWidthFraction: CGFloat = 5.0 / 36.0

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2.0
        let bandWidth = min(rect.width, rect.height) * Self.bandWidthFraction
        let innerRadius = max(outerRadius - bandWidth, 0)
        let clamped = max(0, min(progress, 1))

        guard clamped > 0, innerRadius > 0 else { return Path() }

        if clamped >= 1 {
            return fullDonut(center: center, outerRadius: outerRadius, innerRadius: innerRadius)
        }

        let start = Angle.degrees(-90)
        let end = Angle.degrees(-90 + 360 * clamped)

        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: start,
            endAngle: end,
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: end,
            endAngle: start,
            clockwise: true
        )
        path.closeSubpath()
        return path
    }

    private func fullDonut(
        center: CGPoint,
        outerRadius: CGFloat,
        innerRadius: CGFloat
    ) -> Path {
        var path = Path()
        path.addArc(
            center: center,
            radius: outerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: false
        )
        path.addArc(
            center: center,
            radius: innerRadius,
            startAngle: .degrees(0),
            endAngle: .degrees(360),
            clockwise: true
        )
        return path
    }
}

// MARK: - Preview

#Preview {
    HStack(spacing: 24) {
        ForEach([0.0, 0.25, 0.6, 0.85, 1.0], id: \.self) { p in
            CircularProgressView(progress: p)
                .frame(width: 36, height: 36)
        }
    }
    .padding()
}

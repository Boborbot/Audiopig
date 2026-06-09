//
//  CircularProgressView.swift
//  Audiopig
//

import SwiftUI

/// A pie + arc progress indicator: a tinted filled sector for "completed" volume
/// overlaid with a crisp accent-colored arc, producing a layered, premium look.
struct CircularProgressView: View {
    let progress: Double // 0…1

    var body: some View {
        ZStack {
            // Background track ring
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 2.5)

            // Filled pie sector — tinted accent for mass/volume feel
            PieSectorShape(progress: progress)
                .fill(Color.accentColor.opacity(0.18))

            // Crisp leading-edge arc on top
            Circle()
                .trim(from: 0, to: min(progress, 1))
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Pie Sector Shape

private struct PieSectorShape: Shape {
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard progress > 0 else { return Path() }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2.0
        let end    = Angle.degrees(-90 + 360 * min(progress, 1))

        var path = Path()
        path.move(to: center)
        path.addArc(
            center:     center,
            radius:     radius,
            startAngle: .degrees(-90),
            endAngle:   end,
            clockwise:  false
        )
        path.closeSubpath()
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

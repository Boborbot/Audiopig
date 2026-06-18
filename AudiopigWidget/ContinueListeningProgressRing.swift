//
//  ContinueListeningProgressRing.swift
//  AudiopigWidget
//

import SwiftUI
import WidgetKit

struct ContinueListeningProgressRing: View {
    let progress: Double
    let accent: Color
    let track: Color
    let prominence: Double

    private let lineWidth: CGFloat = 3.5

    var body: some View {
        ZStack {
            Circle()
                .stroke(track.opacity(0.28 * prominence), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(
                    accent.opacity(prominence),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .widgetAccentable()
        }
    }
}

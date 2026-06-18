//
//  LockScreenPigGlyph.swift
//  AudiopigWidget
//
//  User-supplied pig glyph on a liquid-glass disc for lock screen widgets.
//

import SwiftUI
import WidgetKit

struct LockScreenGlassPigView: View {
    let prominence: Double

    var body: some View {
        ZStack {
            glassDisc

            Image("LockScreenPigGlyph")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundStyle(Color.primary.opacity(0.94 * prominence))
                .scaleEffect(1.3)
                .padding(1)
                .widgetAccentable()
        }
        .padding(1)
    }

    private var glassDisc: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.34 * prominence),
                            Color.white.opacity(0.14 * prominence),
                            Color.white.opacity(0.04 * prominence),
                        ],
                        center: UnitPoint(x: 0.32, y: 0.28),
                        startRadius: 0,
                        endRadius: 28
                    )
                )

            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22 * prominence),
                            Color.clear,
                            Color.black.opacity(0.06 * prominence),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.62 * prominence),
                            Color.white.opacity(0.18 * prominence),
                            Color.white.opacity(0.08 * prominence),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.1
                )
        }
    }
}

#if DEBUG
struct LockScreenGlassPigView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            LockScreenGlassPigView(prominence: 1)
                .frame(width: 72, height: 72)
        }
    }
}
#endif

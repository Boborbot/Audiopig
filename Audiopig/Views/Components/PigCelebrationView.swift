//
//  PigCelebrationView.swift
//  Audiopig
//

import SwiftUI

// MARK: - Pig Face

/// A minimal pig face drawn entirely with SwiftUI shapes, coloured in brand coral.
private struct PigFaceView: View {
    var body: some View {
        ZStack {
            ears
            head
            snout
            nostrils
            eyes
            arms
        }
        .frame(width: 100, height: 110)
    }

    private var head: some View {
        Circle()
            .fill(DS.Color.coral)
            .frame(width: 84, height: 84)
            .offset(y: 8)
    }

    private var ears: some View {
        HStack(spacing: 44) {
            Circle()
                .fill(DS.Color.coral)
                .frame(width: 28, height: 28)
            Circle()
                .fill(DS.Color.coral)
                .frame(width: 28, height: 28)
        }
        .offset(y: -28)
    }

    private var snout: some View {
        Ellipse()
            .fill(DS.Color.pigSnout)
            .frame(width: 40, height: 26)
            .offset(y: 26)
    }

    private var nostrils: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: 6, height: 6)
            Circle()
                .fill(.black.opacity(0.35))
                .frame(width: 6, height: 6)
        }
        .offset(y: 29)
    }

    private var eyes: some View {
        HStack(spacing: 22) {
            Circle()
                .fill(.black.opacity(0.70))
                .frame(width: 8, height: 8)
            Circle()
                .fill(.black.opacity(0.70))
                .frame(width: 8, height: 8)
        }
        .offset(y: 10)
    }

    /// Two short arms raised in celebration.
    private var arms: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DS.Color.coral)
                .frame(width: 10, height: 28)
                .rotationEffect(.degrees(-40))
                .offset(x: -56, y: 28)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(DS.Color.coral)
                .frame(width: 10, height: 28)
                .rotationEffect(.degrees(40))
                .offset(x: 56, y: 28)
        }
    }
}

// MARK: - Star Burst

private struct StarBurstView: View {
    let isVisible: Bool

    private struct StarConfig: Identifiable {
        let id: Int
        let angle: Double     // degrees
        let distance: CGFloat
        let scale: CGFloat
    }

    private let stars: [StarConfig] = [
        StarConfig(id: 0, angle: -90,  distance: 110, scale: 1.0),
        StarConfig(id: 1, angle: -18,  distance: 100, scale: 0.75),
        StarConfig(id: 2, angle:  54,  distance: 108, scale: 0.85),
        StarConfig(id: 3, angle: 126,  distance: 100, scale: 0.70),
        StarConfig(id: 4, angle: 198,  distance: 106, scale: 0.80),
    ]

    var body: some View {
        ZStack {
            ForEach(stars) { star in
                Image(systemName: "star.fill")
                    .font(.system(size: 18 * star.scale))
                    .foregroundStyle(DS.Color.coral)
                    .offset(starOffset(for: star))
                    .opacity(isVisible ? 1 : 0)
                    .scaleEffect(isVisible ? 1 : 0.1, anchor: .center)
                    .animation(
                        DS.Animation.reveal.delay(Double(star.id) * 0.04),
                        value: isVisible
                    )
            }
        }
    }

    private func starOffset(for star: StarConfig) -> CGSize {
        let radians = star.angle * .pi / 180
        return CGSize(
            width:  cos(radians) * star.distance,
            height: sin(radians) * star.distance
        )
    }
}

// MARK: - Celebration View

/// Full-screen overlay that celebrates finishing a book.
/// Appears automatically; auto-dismisses after 2.5 s or on tap.
struct PigCelebrationView: View {
    let book: Audiobook
    let onDismiss: () -> Void

    @State private var isContentVisible = false

    var body: some View {
        ZStack {
            // Scrim
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: DS.Spacing.lg) {
                ZStack {
                    StarBurstView(isVisible: isContentVisible)
                    PigFaceView()
                        .scaleEffect(isContentVisible ? 1 : 0.1, anchor: .center)
                        .animation(DS.Animation.reveal, value: isContentVisible)
                }
                .frame(width: 260, height: 260)

                VStack(spacing: DS.Spacing.xs) {
                    Text("You finished it!")
                        .font(DS.Typography.sectionHeader)
                        .foregroundStyle(.white)

                    Text(book.title)
                        .font(DS.Typography.listTitle)
                        .foregroundStyle(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .padding(.horizontal, DS.Spacing.xl)
                }
                .opacity(isContentVisible ? 1 : 0)
                .animation(DS.Animation.fade, value: isContentVisible)

                Button("Dismiss") { dismiss() }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .opacity(isContentVisible ? 1 : 0)
                    .animation(DS.Animation.fade.delay(0.3), value: isContentVisible)
            }
        }
        .onAppear {
            withAnimation(DS.Animation.reveal) {
                isContentVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                dismiss()
            }
        }
        .transition(.scale(scale: 0.85).combined(with: .opacity))
    }

    private func dismiss() {
        withAnimation(DS.Animation.fade) {
            isContentVisible = false
        }
        // Give the fade-out a moment before telling the parent to remove the view.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            onDismiss()
        }
    }
}

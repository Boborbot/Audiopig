//
//  IconUnlockOverlay.swift
//  Audiopig
//
//  Full-screen celebratory overlay shown when the user finishes a book
//  that pushes their total listened hours over a new icon tier threshold.
//
//  Animation sequence:
//    0.00s  Card slides up + scales in (spring)
//    0.45s  Outer pulse rings begin expanding
//    0.60s  Lock icon shakes
//    0.85s  Lock snaps open (spring pop)
//    1.00s  Sparkle particles fly out
//    5.00s  Auto-dismiss (or tap anywhere to dismiss early)
//

import SwiftUI

struct IconUnlockOverlay: View {

    let tier: AppIconTier
    let onDismiss: () -> Void

    // MARK: - Animation state

    @State private var cardVisible   = false
    @State private var pulseExpand   = false
    @State private var lockShake     = false
    @State private var lockOpen      = false
    @State private var sparkleOut    = false
    @State private var autoDismissTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            backdrop
            card
        }
        .opacity(cardVisible ? 1 : 0)
        .onAppear { runSequence() }
        .onDisappear { autoDismissTask?.cancel() }
    }

    // MARK: - Backdrop

    private var backdrop: some View {
        Color.black.opacity(0.60)
            .ignoresSafeArea()
            .onTapGesture { dismiss() }
    }

    // MARK: - Card

    private var card: some View {
        VStack(spacing: DS.Spacing.xl) {
            badge
            textBlock
            dismissButton
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.xl)
        .floatingPanel()
        .padding(.horizontal, DS.Spacing.xl)
        .offset(y: cardVisible ? 0 : 60)
        .scaleEffect(cardVisible ? 1 : 0.88)
    }

    // MARK: - Badge

    private var badge: some View {
        ZStack {
            pulseRing(delay: 0)
            pulseRing(delay: 0.18)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [DS.Color.coral, DS.Color.coral.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 88, height: 88)
                .applyShadows(DS.Shadow.playButton)

            Image(systemName: lockOpen ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(.white)
                .rotationEffect(lockShakeAngle)
                .scaleEffect(lockOpen ? 1.15 : 1.0)
                .animation(
                    .spring(response: 0.38, dampingFraction: 0.50),
                    value: lockOpen
                )

            if sparkleOut {
                sparkleRing
            }
        }
        .frame(height: 130)
    }

    private var lockShakeAngle: Angle {
        if lockOpen { return .degrees(0) }
        return .degrees(lockShake ? -14 : 0)
    }

    // MARK: - Pulse ring helper

    private func pulseRing(delay: Double) -> some View {
        Circle()
            .strokeBorder(DS.Color.coral.opacity(pulseExpand ? 0 : 0.35), lineWidth: 2)
            .frame(width: pulseExpand ? 200 : 88)
            .animation(
                .easeOut(duration: 1.4)
                .repeatForever(autoreverses: false)
                .delay(delay),
                value: pulseExpand
            )
    }

    // MARK: - Sparkle ring

    private var sparkleRing: some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                SparkleParticle(index: i, animate: sparkleOut)
            }
        }
    }

    // MARK: - Text

    private var textBlock: some View {
        VStack(spacing: DS.Spacing.sm) {
            Text("Icon Unlocked!")
                .font(.custom("ClashDisplay-Bold", size: 24))
                .foregroundStyle(DS.Color.primary)

            Text(tier.label)
                .font(.custom("ClashDisplay-Semibold", size: 20))
                .foregroundStyle(DS.Color.coral)

            Text(tier.unlockDescription)
                .font(.subheadline)
                .foregroundStyle(DS.Color.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, DS.Spacing.xs)
        }
    }

    // MARK: - Button

    private var dismissButton: some View {
        Button("Awesome!") { dismiss() }
            .buttonStyle(DS.ButtonStyle.primary())
    }

    // MARK: - Animation sequence

    private func runSequence() {
        withAnimation(DS.Animation.reveal) {
            cardVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            withAnimation { pulseExpand = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
            withAnimation(.easeInOut(duration: 0.10).repeatCount(5, autoreverses: true)) {
                lockShake = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.85) {
            withAnimation { lockOpen = true }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.00) {
            withAnimation(DS.Animation.standard) { sparkleOut = true }
        }

        autoDismissTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { dismiss() }
        }
    }

    // MARK: - Dismiss

    private func dismiss() {
        autoDismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.22)) { cardVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) { onDismiss() }
    }
}

// MARK: - Sparkle Particle

private struct SparkleParticle: View {
    let index: Int
    let animate: Bool

    private var angleDeg: Double { Double(index) * 45.0 }
    private var distance: CGFloat { index % 2 == 0 ? 68 : 54 }
    private var size: CGFloat { index % 3 == 0 ? 12 : 9 }
    private var color: Color { index % 3 == 0 ? DS.Color.coral : .yellow }

    private var offsetX: CGFloat { distance * cos(angleDeg * .pi / 180) }
    private var offsetY: CGFloat { distance * sin(angleDeg * .pi / 180) }

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: size, weight: .bold))
            .foregroundStyle(color)
            .offset(x: animate ? offsetX : 0,
                    y: animate ? offsetY : 0)
            .opacity(animate ? 0 : 1)
            .animation(
                .easeOut(duration: 0.75).delay(Double(index) * 0.04),
                value: animate
            )
    }
}

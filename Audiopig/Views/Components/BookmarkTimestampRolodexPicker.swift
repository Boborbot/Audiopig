//
//  BookmarkTimestampRolodexPicker.swift
//  Audiopig
//

import SwiftUI

/// Minimal vertical rolodex for bookmark timestamps — one drum per digit, grouped as MM : SS (and H when needed).
struct BookmarkTimestampRolodexPicker: View {
    @Binding var timestamp: TimeInterval
    let maxTimestamp: TimeInterval

    @State private var hour: Int
    @State private var minuteTens: Int
    @State private var minuteOnes: Int
    @State private var secondTens: Int
    @State private var secondOnes: Int

    private var maxHour: Int { max(0, Int(maxTimestamp) / 3600) }
    private var showsHours: Bool { maxHour > 0 }

    init(timestamp: Binding<TimeInterval>, maxTimestamp: TimeInterval) {
        _timestamp = timestamp
        self.maxTimestamp = maxTimestamp
        let total = Int(max(0, timestamp.wrappedValue.rounded(.down)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        _hour = State(initialValue: h)
        _minuteTens = State(initialValue: m / 10)
        _minuteOnes = State(initialValue: m % 10)
        _secondTens = State(initialValue: s / 10)
        _secondOnes = State(initialValue: s % 10)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.input, style: .continuous)
                .fill(DS.Color.secondarySurface.opacity(0.55))
                .frame(height: Layout.rowHeight - 4)
                .allowsHitTesting(false)

            HStack(spacing: DS.Spacing.sm) {
                if showsHours {
                    RolodexWheel(values: hourLabels, selection: $hour)
                    rolodexColon
                }

                digitPair(tens: $minuteTens, ones: $minuteOnes)
                rolodexColon
                digitPair(tens: $secondTens, ones: $secondOnes)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.md)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Timestamp")
        .accessibilityValue(PlayerViewModel.formatTime(timestamp))
        .onChange(of: hour) { _, _ in syncFromDigits() }
        .onChange(of: minuteTens) { _, _ in syncFromDigits() }
        .onChange(of: minuteOnes) { _, _ in syncFromDigits() }
        .onChange(of: secondTens) { _, _ in syncFromDigits() }
        .onChange(of: secondOnes) { _, _ in syncFromDigits() }
        .onChange(of: timestamp) { _, newValue in
            applyDigits(from: newValue)
        }
    }

    private var hourLabels: [String] {
        (0...maxHour).map(String.init)
    }

    private var rolodexColon: some View {
        Text(":")
            .font(.system(.title3, design: .rounded).weight(.semibold).monospacedDigit())
            .foregroundStyle(DS.Color.tertiary)
            .padding(.horizontal, DS.Spacing.xs)
            .accessibilityHidden(true)
    }

    private func digitPair(tens: Binding<Int>, ones: Binding<Int>) -> some View {
        HStack(spacing: 2) {
            RolodexWheel(values: RolodexWheel.tensLabels, selection: tens)
            RolodexWheel(values: RolodexWheel.onesLabels, selection: ones)
        }
    }

    private func syncFromDigits() {
        let composed = TimeInterval(
            hour * 3600
                + (minuteTens * 10 + minuteOnes) * 60
                + secondTens * 10 + secondOnes
        )
        let clamped = min(max(0, composed), max(0, maxTimestamp))
        if clamped != composed {
            applyDigits(from: clamped)
        }
        if timestamp != clamped {
            timestamp = clamped
        }
    }

    private func applyDigits(from value: TimeInterval) {
        let total = Int(max(0, value.rounded(.down)))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60

        if hour != h { hour = min(h, maxHour) }
        let newMinuteTens = m / 10
        let newMinuteOnes = m % 10
        let newSecondTens = s / 10
        let newSecondOnes = s % 10
        if minuteTens != newMinuteTens { minuteTens = newMinuteTens }
        if minuteOnes != newMinuteOnes { minuteOnes = newMinuteOnes }
        if secondTens != newSecondTens { secondTens = newSecondTens }
        if secondOnes != newSecondOnes { secondOnes = newSecondOnes }
    }
}

// MARK: - Rolodex Wheel

private struct RolodexWheel: View {
    static let tensLabels = (0...5).map(String.init)
    static let onesLabels = (0...9).map(String.init)

    let values: [String]
    @Binding var selection: Int

    @State private var scrollPosition: Int?

    private let visibleRows = 3

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                Color.clear.frame(height: Layout.rowHeight)
                ForEach(values.indices, id: \.self) { index in
                    Text(values[index])
                        .font(.system(.title2, design: .rounded).weight(.semibold).monospacedDigit())
                        .foregroundStyle(index == selection ? DS.Color.primary : DS.Color.tertiary.opacity(0.5))
                        .scaleEffect(index == selection ? 1.0 : 0.86)
                        .animation(DS.Animation.snappy, value: selection)
                        .frame(width: Layout.columnWidth, height: Layout.rowHeight)
                        .id(index)
                }
                Color.clear.frame(height: Layout.rowHeight)
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPosition, anchor: .center)
        .frame(width: Layout.columnWidth, height: Layout.rowHeight * CGFloat(visibleRows))
        .mask { rolodexFadeMask }
        .onAppear {
            scrollPosition = clampedSelection
        }
        .onChange(of: scrollPosition) { _, newValue in
            guard let newValue else { return }
            let clamped = min(max(0, newValue), values.count - 1)
            guard clamped != selection else { return }
            selection = clamped
            Haptics.subtle()
        }
        .onChange(of: selection) { _, newValue in
            let clamped = min(max(0, newValue), values.count - 1)
            if scrollPosition != clamped {
                scrollPosition = clamped
            }
        }
    }

    private var clampedSelection: Int {
        min(max(0, selection), max(0, values.count - 1))
    }

    private var rolodexFadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.clear, .black],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Layout.rowHeight * 0.65)

            Rectangle()

            LinearGradient(
                colors: [.black, .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: Layout.rowHeight * 0.65)
        }
    }
}

// MARK: - Layout

private enum Layout {
    static let rowHeight: CGFloat = 42
    static let columnWidth: CGFloat = 34
}

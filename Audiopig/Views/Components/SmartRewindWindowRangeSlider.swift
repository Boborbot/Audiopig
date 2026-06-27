//
//  SmartRewindWindowRangeSlider.swift
//  Audiopig
//

import SwiftUI

/// Dual-thumb range slider for Smart Rewind look windows. Right edge is Now; left is further back.
struct SmartRewindWindowRangeSlider: View {
    let scopeKind: SmartRewindScopeKind
    @Binding var startOffset: TimeInterval
    @Binding var endOffset: TimeInterval

    private let thumbSize: CGFloat = 20
    private let trackHeight: CGFloat = 4
    private let selectionHeight: CGFloat = 6

    @State private var activeDrag: ActiveDrag?

    private struct ActiveDrag {
        enum Thumb {
            case start
            case end
        }

        let thumb: Thumb
        let originOffset: TimeInterval
    }

    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            timestampLabels

            GeometryReader { geometry in
                let inset = DS.Spacing.sm
                let trackWidth = max(1, geometry.size.width - inset * 2)
                // startOffset = far edge (left); endOffset = near edge (right)
                let farThumbX = xPosition(for: startOffset, trackWidth: trackWidth) + inset
                let nearThumbX = xPosition(for: endOffset, trackWidth: trackWidth) + inset
                let trackY = (geometry.size.height - selectionHeight) / 2
                let centerY = geometry.size.height / 2

                ZStack(alignment: .topLeading) {
                    trackSegments(
                        trackWidth: trackWidth,
                        inset: inset,
                        farThumbX: farThumbX,
                        nearThumbX: nearThumbX,
                        y: trackY
                    )
                    thumb(at: nearThumbX, centerY: centerY)
                        .highPriorityGesture(nearThumbGesture(trackWidth: trackWidth))
                    thumb(at: farThumbX, centerY: centerY)
                        .highPriorityGesture(farThumbGesture(trackWidth: trackWidth))
                }
            }
            .frame(height: 36)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: DS.Radius.input, style: .continuous)
                    .fill(DS.Color.secondarySurface)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Search window")
            .accessibilityValue(accessibilityValue)
            .accessibilityAdjustableAction { direction in
                adjustForAccessibility(direction)
            }

            axisLabels
        }
    }

    private var timestampLabels: some View {
        HStack {
            Text(startLabel)
                .font(DS.Typography.controlLabel.monospacedDigit())
                .foregroundStyle(DS.Color.coral)
            Spacer()
            Text(endLabel)
                .font(DS.Typography.controlLabel.monospacedDigit())
                .foregroundStyle(DS.Color.coral)
        }
    }

    private var axisLabels: some View {
        HStack {
            Text("Earlier")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)
            Spacer()
            Text("Now")
                .font(DS.Typography.caption)
                .foregroundStyle(DS.Color.secondary)
        }
    }

    private var startLabel: String {
        SmartRewindWindowPolicy.formatOffsetLabel(startOffset)
    }

    private var endLabel: String {
        SmartRewindWindowPolicy.formatOffsetLabel(
            endOffset,
            allowsNow: scopeKind == .near
        )
    }

    private var accessibilityValue: String {
        "\(startLabel) to \(endLabel)"
    }

    private func trackSegments(
        trackWidth: CGFloat,
        inset: CGFloat,
        farThumbX: CGFloat,
        nearThumbX: CGFloat,
        y: CGFloat
    ) -> some View {
        let trackEnd = inset + trackWidth
        let leadingWidth = max(0, farThumbX - inset)
        let selectionWidth = max(0, nearThumbX - farThumbX)
        let trailingWidth = max(0, trackEnd - nearThumbX)
        let barY = y + (selectionHeight - trackHeight) / 2

        return ZStack(alignment: .topLeading) {
            if leadingWidth > 0 {
                Capsule()
                    .fill(Color(UIColor.systemGray4))
                    .frame(width: leadingWidth, height: trackHeight)
                    .offset(x: inset, y: barY)
            }

            if selectionWidth > 0 {
                Capsule()
                    .fill(DS.Color.coral)
                    .frame(width: selectionWidth, height: selectionHeight)
                    .offset(x: farThumbX, y: y)
            }

            if trailingWidth > 0 {
                Capsule()
                    .fill(Color(UIColor.systemGray4))
                    .frame(width: trailingWidth, height: trackHeight)
                    .offset(x: nearThumbX, y: barY)
            }
        }
    }

    private func thumb(at x: CGFloat, centerY: CGFloat) -> some View {
        Circle()
            .fill(Color.white)
            .overlay {
                Circle()
                    .strokeBorder(Color.black.opacity(0.06), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: 1)
            .frame(width: thumbSize, height: thumbSize)
            .offset(x: x - thumbSize / 2, y: centerY - thumbSize / 2)
    }

    private func farThumbGesture(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                applyDrag(
                    thumb: .start,
                    translation: drag.translation.width,
                    trackWidth: trackWidth
                )
            }
            .onEnded { _ in
                activeDrag = nil
            }
    }

    private func nearThumbGesture(trackWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                applyDrag(
                    thumb: .end,
                    translation: drag.translation.width,
                    trackWidth: trackWidth
                )
            }
            .onEnded { _ in
                activeDrag = nil
            }
    }

    private func applyDrag(
        thumb: ActiveDrag.Thumb,
        translation: CGFloat,
        trackWidth: CGFloat
    ) {
        if activeDrag?.thumb != thumb {
            activeDrag = ActiveDrag(
                thumb: thumb,
                originOffset: thumb == .start ? startOffset : endOffset
            )
        }

        guard let drag = activeDrag else { return }

        let usableWidth = max(1, trackWidth - thumbSize)
        let trackMax = SmartRewindWindowPolicy.trackUpperBound(for: scopeKind)
        let deltaOffset = -(Double(translation) / Double(usableWidth)) * trackMax
        let raw = drag.originOffset + deltaOffset

        switch thumb {
        case .start:
            let step = SmartRewindWindowPolicy.startSliderStep(for: scopeKind)
            let snapped = SmartRewindWindowPolicy.snappedOffset(raw, step: step)
            startOffset = SmartRewindWindowPolicy.clampedStartOffset(
                snapped,
                end: endOffset,
                for: scopeKind
            )
        case .end:
            let step = SmartRewindWindowPolicy.endSliderStep(for: scopeKind)
            let snapped = SmartRewindWindowPolicy.snappedOffset(raw, step: step)
            endOffset = SmartRewindWindowPolicy.clampedEndOffset(
                snapped,
                start: startOffset,
                for: scopeKind
            )
        }
    }

    private func xPosition(for offset: TimeInterval, trackWidth: CGFloat) -> CGFloat {
        let usableWidth = max(1, trackWidth - thumbSize)
        let trackMax = SmartRewindWindowPolicy.trackUpperBound(for: scopeKind)
        let fraction = min(max(offset / trackMax, 0), 1)
        return thumbSize / 2 + usableWidth * (1 - fraction)
    }

    private func adjustForAccessibility(_ direction: AccessibilityAdjustmentDirection) {
        let delta: TimeInterval = direction == .increment ? 1 : -1

        if startOffset - endOffset <= SmartRewindWindowPolicy.minimumGap(for: scopeKind) + 1 {
            let endStep = SmartRewindWindowPolicy.endSliderStep(for: scopeKind)
            let endDelta = delta * endStep
            let snappedEnd = SmartRewindWindowPolicy.snappedOffset(
                endOffset + endDelta,
                step: endStep
            )
            endOffset = SmartRewindWindowPolicy.clampedEndOffset(
                snappedEnd,
                start: startOffset,
                for: scopeKind
            )
        } else {
            let startStep = SmartRewindWindowPolicy.startSliderStep(for: scopeKind)
            let startDelta = delta * startStep
            let snappedStart = SmartRewindWindowPolicy.snappedOffset(
                startOffset + startDelta,
                step: startStep
            )
            startOffset = SmartRewindWindowPolicy.clampedStartOffset(
                snappedStart,
                end: endOffset,
                for: scopeKind
            )
        }
    }
}

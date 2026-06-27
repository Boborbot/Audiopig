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

    private let thumbSize: CGFloat = 28
    private let trackHeight: CGFloat = 4

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
                let width = geometry.size.width
                let startX = xPosition(for: startOffset, trackWidth: width)
                let endX = xPosition(for: endOffset, trackWidth: width)
                let trackY = (geometry.size.height - trackHeight) / 2

                ZStack(alignment: .topLeading) {
                    trackBackground(width: width, y: trackY)
                    selectionFill(from: endX, to: startX, y: trackY)
                    thumb(at: endX, y: trackY)
                        .highPriorityGesture(endThumbGesture(trackWidth: width))
                    thumb(at: startX, y: trackY)
                        .highPriorityGesture(startThumbGesture(trackWidth: width))
                }
            }
            .frame(height: 44)
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

    private func trackBackground(width: CGFloat, y: CGFloat) -> some View {
        Capsule()
            .fill(DS.Color.separator.opacity(0.45))
            .frame(width: max(0, width - thumbSize), height: trackHeight)
            .offset(x: thumbSize / 2, y: y)
    }

    private func selectionFill(from endX: CGFloat, to startX: CGFloat, y: CGFloat) -> some View {
        Capsule()
            .fill(DS.Color.coral)
            .frame(width: max(0, startX - endX), height: trackHeight)
            .offset(x: endX, y: y)
    }

    private func thumb(at x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(DS.Color.canvasSurface)
            .overlay {
                Circle()
                    .strokeBorder(DS.Color.coral, lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            .frame(width: thumbSize, height: thumbSize)
            .offset(x: x - thumbSize / 2, y: y - (thumbSize - trackHeight) / 2)
    }

    private func startThumbGesture(trackWidth: CGFloat) -> some Gesture {
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

    private func endThumbGesture(trackWidth: CGFloat) -> some Gesture {
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

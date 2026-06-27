//
//  SmartRewindScopeSheet.swift
//  Audiopig
//

import SwiftUI

/// Temporary Look Near / Look Far window controls shown on long press.
struct SmartRewindScopeSheet: View {
    let title: String
    let scopeKind: SmartRewindScopeKind
    let onLook: (SmartRewindWindowOffsets) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var startOffset: TimeInterval
    @State private var endOffset: TimeInterval

    init(
        title: String,
        scopeKind: SmartRewindScopeKind,
        defaultOffsets: SmartRewindWindowOffsets,
        onLook: @escaping (SmartRewindWindowOffsets) -> Void
    ) {
        let clamped = SmartRewindWindowPolicy.clampedOffsets(defaultOffsets, for: scopeKind)
        self.title = title
        self.scopeKind = scopeKind
        self.onLook = onLook
        _startOffset = State(initialValue: clamped.startOffset)
        _endOffset = State(initialValue: clamped.endOffset)
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            header

            SmartRewindOffsetControls(
                title: title,
                scopeKind: scopeKind,
                startOffset: $startOffset,
                endOffset: $endOffset
            )
            .padding(.horizontal, DS.Spacing.md)

            Button(action: runLook) {
                HStack(spacing: 6) {
                    Image(systemName: "waveform.and.magnifyingglass")
                    Text("Look")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DS.ButtonStyle.pill(isActive: true))
            .padding(.horizontal, DS.Spacing.md)
        }
        .padding(.top, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheetGlass()
        .presentationDetents([.fraction(0.38)])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.primary)
            Spacer()
        }
        .padding(.horizontal, DS.Spacing.lg)
    }

    private func runLook() {
        let offsets = SmartRewindWindowPolicy.clampedOffsets(
            SmartRewindWindowOffsets(startOffset: startOffset, endOffset: endOffset),
            for: scopeKind
        )
        dismiss()
        onLook(offsets)
    }
}

/// Look Near / Look Far pill: tap runs with defaults, long press opens scope sheet.
struct SmartRewindTriggerButton: View {
    let title: String
    let pillPadding: CGFloat
    let isEnabled: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void

    @State private var suppressNextTap = false

    var body: some View {
        Button {
            if suppressNextTap {
                suppressNextTap = false
                return
            }
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "waveform.and.magnifyingglass")
                Text(title)
            }
            .pillAppearance(verticalPadding: pillPadding)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    guard isEnabled else { return }
                    suppressNextTap = true
                    Haptics.subtle()
                    onLongPress()
                }
        )
        .accessibilityHint("Long press to adjust the time window")
    }
}

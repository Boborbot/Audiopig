//
//  SmartRewindScopeSettingsBubble.swift
//  Audiopig
//

import SwiftUI

/// Persistent Look Far / Look Near window controls shown in playback settings.
struct SmartRewindScopeSettingsBubble: View {
    let title: String
    let scopeKind: SmartRewindScopeKind
    @Binding var startOffset: TimeInterval
    @Binding var endOffset: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(title)
                .font(DS.Typography.sectionHeader)
                .foregroundStyle(DS.Color.primary)
                .accessibilityAddTraits(.isHeader)

            SmartRewindOffsetControls(
                title: title,
                scopeKind: scopeKind,
                startOffset: $startOffset,
                endOffset: $endOffset
            )
        }
        .padding(DS.Spacing.md)
        .floatingPanel()
    }
}

/// Shared dual-thumb window slider for Smart Rewind scope sheets and settings bubbles.
struct SmartRewindOffsetControls: View {
    let title: String
    let scopeKind: SmartRewindScopeKind
    @Binding var startOffset: TimeInterval
    @Binding var endOffset: TimeInterval

    var body: some View {
        SmartRewindWindowRangeSlider(
            scopeKind: scopeKind,
            startOffset: $startOffset,
            endOffset: $endOffset
        )
        .accessibilityLabel(title)
    }
}

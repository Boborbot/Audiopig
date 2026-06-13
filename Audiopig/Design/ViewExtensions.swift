//
//  ViewExtensions.swift
//  Audiopig
//
//  Thin convenience wrappers that keep view bodies readable.
//  Each extension maps a common styling intent to the correct DS token — callers
//  express intent, not implementation.
//

import SwiftUI

// MARK: - Foreground / Color

extension View {
    /// Sets the foreground to the Audiopig brand coral.
    func coralAccent() -> some View {
        foregroundStyle(DS.Color.coral)
    }

    /// Sets the foreground to the standard secondary label color.
    func secondaryLabel() -> some View {
        foregroundStyle(DS.Color.secondary)
    }
}

// MARK: - Typography

extension View {
    /// Applies the section/banner header style (headline, semibold) in coral.
    /// Use for NavigationTitle replacements, library section labels, and settings banners.
    func sectionTitle() -> some View {
        self
            .font(DS.Typography.sectionHeader)
            .foregroundStyle(DS.Color.coral)
    }

    /// Applies the player hero title style (serif, title2 bold).
    func playerTitleStyle() -> some View {
        font(DS.Typography.playerTitle)
    }

    /// Applies the timestamp monospaced caption style.
    func timestampStyle() -> some View {
        font(DS.Typography.timestamp)
            .foregroundStyle(DS.Color.secondary)
    }
}

// MARK: - Cover Art

extension View {
    /// Standard rounded-rectangle clip for cover art in the full player.
    func playerCoverArtClip() -> some View {
        clipShape(RoundedRectangle(cornerRadius: DS.Radius.coverArt, style: .continuous))
    }

    /// Standard rounded-rectangle clip for cover art in list rows.
    func listCoverArtClip() -> some View {
        clipShape(RoundedRectangle(cornerRadius: DS.Radius.chip, style: .continuous))
    }
}

// MARK: - Card

extension View {
    /// Wraps a list row content in a floating glass card with horizontal padding.
    func libraryCard() -> some View {
        self
            .floatingPanel()
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Coral Active Indicator

extension View {
    /// Adds a 3-pt coral capsule on the leading edge — used for active chapter/bookmark rows.
    func coralActiveIndicator(isActive: Bool) -> some View {
        overlay(alignment: .leading) {
            if isActive {
                Capsule()
                    .fill(DS.Color.coral)
                    .frame(width: 3)
                    .padding(.vertical, DS.Spacing.sm)
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }
}

// MARK: - Pill Visual Appearance (for Menu labels and non-Button contexts)

extension View {
    /// Applies the pill visual appearance without button interaction behavior.
    /// Use this on Menu labels and any non-Button element that should look like a pill control.
    func pillAppearance(isActive: Bool = false, verticalPadding: CGFloat = 9) -> some View {
        self
            .font(DS.Typography.controlLabel)
            .foregroundStyle(isActive ? DS.Color.coral : DS.Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, verticalPadding)
            .background(Capsule().fill(Color(UIColor.secondarySystemBackground)))
    }
}

// MARK: - Coral Navigation Banner

extension View {
    /// Applies Liquid Glass to the NavigationStack bar with coral title typography.
    ///
    /// The bar background is system-managed Liquid Glass (transparent appearance).
    /// Titles render in `DS.Color.coral` (Clash Display Bold at large size).
    /// Bar items are tinted coral. Apply to the root content inside a NavigationStack.
    func coralNavigationBanner() -> some View {
        self
            .navigationBarTitleDisplayMode(.large)
            .onAppear { DS.applyCoralNavigationBarAppearance() }
    }
}

// MARK: - Drag Handle

extension View {
    /// Standard sheet drag indicator in coral tint.
    func coralDragIndicator() -> some View {
        overlay(alignment: .top) {
            Capsule()
                .fill(DS.Color.coral.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
        }
    }
}

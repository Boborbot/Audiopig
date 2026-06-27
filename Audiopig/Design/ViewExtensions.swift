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

    /// Fixed-size capsule for the five player accessory controls — sized to the widest speed label, nothing larger.
    func playerAccessoryPill(isActive: Bool = false, style: PlayerAccessoryPillStyle = .icon) -> some View {
        let height = DS.Layout.playerAccessoryPillHeight
        let width = style == .speed ? DS.Layout.playerSpeedPillWidth : DS.Layout.playerIconPillWidth
        return self
            .font(DS.Typography.controlLabel)
            .foregroundStyle(isActive ? DS.Color.coral : DS.Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(width: width, height: height)
            .background(Capsule().fill(Color(UIColor.secondarySystemBackground)))
            .fixedSize(horizontal: true, vertical: true)
    }
}

enum PlayerAccessoryPillStyle {
    case speed
    case icon
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

// MARK: - Background Layout Snap

/// Rebuilds this subtree without animation when the app backgrounds or returns
/// from background so in-flight SwiftUI springs cannot freeze mid-transition.
private struct SnapLayoutOnBackgroundModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var layoutToken = 0
    @State private var wasBackgrounded = false

    func body(content: Content) -> some View {
        content
            .id(layoutToken)
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    wasBackgrounded = true
                    snapLayout()
                } else if phase == .active, wasBackgrounded {
                    wasBackgrounded = false
                    snapLayout()
                }
            }
    }

    private func snapLayout() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            layoutToken += 1
        }
    }
}

extension View {
    func snapLayoutOnBackgroundTransition() -> some View {
        modifier(SnapLayoutOnBackgroundModifier())
    }
}

// MARK: - Mini Player Scroll Clearance

private struct MiniPlayerClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    /// Bottom inset (pt) that scroll content should reserve when the mini player is visible.
    var miniPlayerClearance: CGFloat {
        get { self[MiniPlayerClearanceKey.self] }
        set { self[MiniPlayerClearanceKey.self] = newValue }
    }
}

extension View {
    /// Extends scrollable content so the last row can rest above the floating mini player.
    func miniPlayerScrollClearance() -> some View {
        modifier(MiniPlayerScrollClearanceModifier())
    }
}

private struct MiniPlayerScrollClearanceModifier: ViewModifier {
    @Environment(\.miniPlayerClearance) private var clearance

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            if clearance > 0 {
                Color.clear
                    .frame(height: clearance)
                    .animation(
                        .spring(response: 0.38, dampingFraction: 0.80),
                        value: clearance
                    )
                    .snapLayoutOnBackgroundTransition()
            }
        }
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

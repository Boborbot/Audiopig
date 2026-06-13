//
//  ButtonStyles.swift
//  Audiopig
//
//  Reusable ButtonStyle implementations.
//  All interactive controls in the app must use one of these — never compose
//  button backgrounds inline inside a view body.
//

import SwiftUI

// MARK: - DS.ButtonStyle Namespace

extension DS {
    enum ButtonStyle {}
}

// MARK: - Player Control (primary play/pause disc — 72 pt)

struct PlayerControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.93 : 1.0)
            .animation(DS.Animation.snappy, value: configuration.isPressed)
    }
}

extension DS.ButtonStyle {
    /// Large circular play/pause button. Wrap label in a coral-filled Circle inside the view.
    static var playerControl: PlayerControlButtonStyle { PlayerControlButtonStyle() }
}

// MARK: - Transport (skip, speed — 36 pt glass disc)

struct TransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(DS.Animation.snappy, value: configuration.isPressed)
    }
}

extension DS.ButtonStyle {
    /// Skip-back, skip-forward, and any secondary transport control.
    static var transport: TransportButtonStyle { TransportButtonStyle() }
}

// MARK: - Primary CTA (coral-filled capsule)

struct PrimaryButtonStyle: ButtonStyle {
    var isDisabled: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.sectionHeader)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.md)
            .background(
                isDisabled ? Color(UIColor.systemGray4) : DS.Color.coral,
                in: RoundedRectangle(cornerRadius: DS.Radius.button, style: .continuous)
            )
            .applyShadows(isDisabled ? [] : DS.Shadow.floatBar)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(DS.Animation.snappy, value: configuration.isPressed)
    }
}

extension DS.ButtonStyle {
    /// Full-width coral CTA button (merge, add, confirm actions).
    static func primary(isDisabled: Bool = false) -> PrimaryButtonStyle {
        PrimaryButtonStyle(isDisabled: isDisabled)
    }
}

// MARK: - Ghost (coral-border capsule)

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.controlLabel)
            .foregroundStyle(DS.Color.coral)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 1)
            .background(
                Capsule()
                    .strokeBorder(DS.Color.coral.opacity(0.55), lineWidth: 1)
                    .background(Capsule().fill(DS.Color.coralSubtle))
            )
            .opacity(configuration.isPressed ? 0.70 : 1.0)
            .animation(DS.Animation.snappy, value: configuration.isPressed)
    }
}

extension DS.ButtonStyle {
    /// Transparent coral-bordered capsule for secondary actions.
    static var ghost: GhostButtonStyle { GhostButtonStyle() }
}

// MARK: - Pill (secondary control pill — speed, chapters, bookmarks, sleep)

struct PillButtonStyle: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DS.Typography.controlLabel)
            .foregroundStyle(isActive ? DS.Color.coral : DS.Color.primary)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color(UIColor.secondarySystemBackground)))
            .opacity(configuration.isPressed ? 0.65 : 1.0)
            .animation(DS.Animation.snappy, value: configuration.isPressed)
    }
}

extension DS.ButtonStyle {
    /// Small pill for player accessory controls (speed, chapters, bookmarks, sleep timer).
    static func pill(isActive: Bool = false) -> PillButtonStyle {
        PillButtonStyle(isActive: isActive)
    }
}

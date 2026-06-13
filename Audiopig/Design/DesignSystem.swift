//
//  DesignSystem.swift
//  Audiopig
//
//  Single source of truth for every visual token in the app.
//  All views and modifiers must consume constants from this namespace —
//  never hardcode hex values, raw CGFloat spacing, or inline font calls.
//

import SwiftUI
import UIKit

// MARK: - Root Namespace

enum DS {

    // MARK: - Color

    enum Color {
        /// #F18470 — the Audiopig brand. Use for one semantic role at a time.
        static let coral = SwiftUI.Color(hex: "#F18470")

        /// Coral at 12 % opacity. Warm tint layer over glass surfaces.
        static let coralSubtle = coral.opacity(0.12)

        /// Coral at 4 % opacity. Barely-there ambient tint on deep glass surfaces.
        static let coralAmbient = coral.opacity(0.04)

        /// Coral at 40 % opacity. Progress ring fill background.
        static let coralMuted = coral.opacity(0.40)

        /// Coral at 55 % opacity. Pig snout fill in the celebration overlay.
        static let pigSnout = coral.opacity(0.55)

        /// Standard adaptive primary label color (auto dark / light).
        static let primary = SwiftUI.Color.primary

        /// Standard adaptive secondary label color.
        static let secondary = SwiftUI.Color.secondary

        /// Standard adaptive tertiary label color.
        static let tertiary = SwiftUI.Color(UIColor.tertiaryLabel)

        /// Separator / hairline color.
        static let separator = SwiftUI.Color(UIColor.separator)

        /// Placeholder artwork background — warm-biased neutral.
        static let artworkPlaceholder = SwiftUI.Color(UIColor.systemGray5)

        /// Secondary surface background (inputs, menus, etc.).
        static let secondarySurface = SwiftUI.Color(UIColor.secondarySystemBackground)

        /// Adaptive page canvas background.
        ///
        /// - Light: `#DDD3C5` — warm sand. Complements coral and tints the nav bar with warmth.
        /// - Dark: `#141518` — cool midnight slate. Keeps the coral accent vivid without warmth clash.
        ///
        /// Uses `UIColor`'s trait-collection closure so it adapts instantly to `preferredColorScheme`
        /// changes and system dark/light transitions with no view-level code.
        static let canvas = SwiftUI.Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x14 / 255.0, green: 0x15 / 255.0, blue: 0x18 / 255.0, alpha: 1) // #141518
                : UIColor(red: 0xDD / 255.0, green: 0xD3 / 255.0, blue: 0xC5 / 255.0, alpha: 1) // #DDD3C5
        })

        /// Adaptive card / floating-panel surface background.
        ///
        /// - Light: `UIColor.secondarySystemBackground` — the system off-white used for list cards.
        /// - Dark: `#1E2026` — slightly elevated slate, distinct from the canvas floor.
        ///
        /// Use this wherever a glass card needs a solid opaque backing in dark mode
        /// (e.g. import overlay, merge bar). Most glass surfaces should still use
        /// `Material` values; this token is for opaque fills only.
        static let canvasSurface = SwiftUI.Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 0x1E / 255.0, green: 0x20 / 255.0, blue: 0x26 / 255.0, alpha: 1) // #1E2026
                : UIColor.secondarySystemBackground
        })
    }

    // MARK: - Rounded System Font Helpers
    //
    // Replaces the previous ClashDisplay custom font.
    // SF Pro Rounded ships on every iOS device — no licensing, no bundled files.
    // The API is identical to the old ClashDisplay helpers so call sites compile
    // unchanged (just swap DS.ClashDisplay → DS.Rounded).

    enum Rounded {
        static func font(_ weight: SwiftUI.Font.Weight = .regular, size: CGFloat) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }

        static func font(_ weight: SwiftUI.Font.Weight = .regular, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
            .system(textStyle, design: .rounded).weight(weight)
        }

        /// Returns a `UIFont` in SF Rounded for use with UIKit APIs (e.g. navigation bar appearance).
        static func uiFont(size: CGFloat, weight: UIFont.Weight = .bold) -> UIFont {
            let descriptor = UIFontDescriptor
                .preferredFontDescriptor(withTextStyle: .largeTitle)
                .withDesign(.rounded)?
                .withSymbolicTraits(weight == .bold ? .traitBold : [])
                ?? UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle)
            return UIFont(descriptor: descriptor, size: size)
        }
    }

    // MARK: - Typography

    enum Typography {
        /// Hero book title in the full player. New York serif — literary register.
        static let playerTitle: SwiftUI.Font = .system(.title2, design: .serif).bold()

        /// Author name beneath the player title. SF Pro callout.
        static let playerAuthor: SwiftUI.Font = .callout

        /// Library / Settings section banners. SF Display headline.
        static let sectionHeader: SwiftUI.Font = .system(.headline, design: .default, weight: .semibold)

        /// Audiobook row title. SF body, semibold.
        static let listTitle: SwiftUI.Font = .system(.callout, design: .default, weight: .semibold)

        /// Chapter / bookmark row body text.
        static let listBody: SwiftUI.Font = .body

        /// Progress text, chapter duration — fixed-width digit alignment.
        static let timestamp: SwiftUI.Font = .caption.monospacedDigit()

        /// Tiny secondary label (progress percentage, metadata, labels).
        static let caption: SwiftUI.Font = .caption

        /// Monospace speed / numeric label in controls.
        static let controlLabel: SwiftUI.Font = .system(.callout, design: .rounded, weight: .semibold)
    }

    // MARK: - Spacing (4-pt grid)

    enum Spacing {
        /// 4 pt — icon-to-label gaps, tight nudges.
        static let xs: CGFloat = 4
        /// 8 pt — intra-group padding.
        static let sm: CGFloat = 8
        /// 16 pt — standard horizontal / vertical padding.
        static let md: CGFloat = 16
        /// 24 pt — between major sections.
        static let lg: CGFloat = 24
        /// 32 pt — screen-edge insets, hero top/bottom breathing room.
        static let xl: CGFloat = 32
        /// 28 pt — player horizontal inset (matches existing layout).
        static let playerH: CGFloat = 28
    }

    // MARK: - Corner Radius

    enum Radius {
        /// 8 pt — small chips, cover art in list rows.
        static let chip: CGFloat = 8
        /// 12 pt — cover art in full player.
        static let coverArt: CGFloat = 12
        /// 16 pt — glass cards and floating panels.
        static let card: CGFloat = 16
        /// 20 pt — sheets and import overlay.
        static let sheet: CGFloat = 20
        /// 14 pt — wide CTA buttons (merge, add, etc.).
        static let button: CGFloat = 14
        /// 10 pt — inline input fields.
        static let input: CGFloat = 10
    }

    // MARK: - Shadow

    enum Shadow {
        struct Recipe {
            let color: SwiftUI.Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        /// Two-layer shadow for cover art card in the player.
        static let coverArt: [Recipe] = [
            Recipe(color: .black.opacity(0.22), radius: 24, x: 0, y: 10),
            Recipe(color: .black.opacity(0.08), radius: 6,  x: 0, y: 2)
        ]

        /// Subtle single-layer shadow for glass list cards.
        static let card: [Recipe] = [
            Recipe(color: .black.opacity(0.10), radius: 12, x: 0, y: 4),
            Recipe(color: .black.opacity(0.04), radius: 3,  x: 0, y: 1)
        ]

        /// Warm coral glow for the primary play/pause button.
        static let playButton: [Recipe] = [
            Recipe(color: DS.Color.coral.opacity(0.45), radius: 16, x: 0, y: 6),
            Recipe(color: DS.Color.coral.opacity(0.15), radius: 4,  x: 0, y: 2)
        ]

        /// Coral glow for the floating merge / CTA bar.
        static let floatBar: [Recipe] = [
            Recipe(color: DS.Color.coral.opacity(0.35), radius: 12, x: 0, y: 4)
        ]
    }

    // MARK: - Animation

    enum Animation {
        /// General-purpose spring: smooth state transitions (e.g. selection, appearance).
        static let standard = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.80)
        /// Fast, crisp spring: toolbar items, icon swaps.
        static let snappy  = SwiftUI.Animation.spring(response: 0.22, dampingFraction: 0.85)
        /// Gentle, roomy spring: hero reveals (player open, cover scale).
        static let reveal  = SwiftUI.Animation.spring(response: 0.45, dampingFraction: 0.75)
        /// Short ease for simple alpha / numeric transitions.
        static let fade    = SwiftUI.Animation.easeInOut(duration: 0.20)
    }
}

// MARK: - Color Hex Init

private extension SwiftUI.Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Shadow View Modifier

extension View {
    /// Applies a stack of DS shadow recipes to a view.
    @ViewBuilder
    func applyShadows(_ recipes: [DS.Shadow.Recipe]) -> some View {
        let base = self
        recipes.reduce(AnyView(base)) { view, recipe in
            AnyView(
                view.shadow(
                    color: recipe.color,
                    radius: recipe.radius,
                    x: recipe.x,
                    y: recipe.y
                )
            )
        }
    }
}

// MARK: - Navigation Bar Appearance

extension DS {
    /// Configures the UINavigationBar with coral brand typography.
    ///
    /// Uses `configureWithTransparentBackground()` so the system's native material
    /// renders behind the bar — no opaque fill. The large title is styled in
    /// `DS.Color.coral` using SF Rounded Bold; the compact title uses the system font
    /// in coral. Bar button items and the back chevron are tinted coral to match.
    ///
    /// All four appearance variants are set explicitly to prevent the compact title from
    /// disappearing when the large title collapses.
    ///
    /// Safe to call multiple times — idempotent.
    static func applyCoralNavigationBarAppearance() {
        let coral = UIColor(red: 0xF1 / 255.0, green: 0x84 / 255.0, blue: 0x70 / 255.0, alpha: 1)

        let largeTitleFont = DS.Rounded.uiFont(size: 34, weight: .bold)

        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.shadowColor = .clear
        appearance.largeTitleTextAttributes = [
            .font: largeTitleFont,
            .foregroundColor: coral
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: coral
        ]

        let proxy = UINavigationBar.appearance()
        proxy.standardAppearance          = appearance
        proxy.scrollEdgeAppearance        = appearance
        proxy.compactAppearance           = appearance
        proxy.compactScrollEdgeAppearance = appearance
        proxy.tintColor = coral
    }
}

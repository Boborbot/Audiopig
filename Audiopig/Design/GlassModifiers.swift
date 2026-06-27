//
//  GlassModifiers.swift
//  Audiopig
//
//  Reusable ViewModifiers that encode Audiopig's warm-glass visual identity.
//  Build all glass surfaces from these — never compose materials inline in views.
//

import SwiftUI
import CoreImage

// MARK: - Warm Glass

/// Ultra-thin system material with a subtle coral warmth overlay.
/// Use for bars, overlays, and any floating surface that should feel light.
private struct WarmGlassModifier: ViewModifier {
    /// Opacity of the coral tint layer (default 0.04 — barely perceptible warmth).
    var tintOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(DS.Color.coral.opacity(tintOpacity))
                }
            }
    }
}

extension View {
    /// Applies an ultra-thin warm-glass background.
    /// - Parameter tintOpacity: Coral overlay opacity. Default 0.04 is tasteful; raise to 0.08 for stronger warmth.
    func warmGlass(tintOpacity: Double = 0.04) -> some View {
        modifier(WarmGlassModifier(tintOpacity: tintOpacity))
    }
}

// MARK: - Floating Panel

/// A regular-weight glass card: used for the player controls panel and any
/// elevated surface that needs more opacity than a bar.
private struct FloatingPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .fill(DS.Color.coralAmbient)
                    RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous)
                        .strokeBorder(DS.Color.coral.opacity(0.08), lineWidth: 0.5)
                }
            }
            .applyShadows(DS.Shadow.card)
    }
}

extension View {
    /// Applies the floating glass card treatment: rounded, regular material, coral ambient tint, subtle stroke + shadow.
    func floatingPanel() -> some View {
        modifier(FloatingPanelModifier())
    }
}

// MARK: - Player Background

/// Full-bleed ambient cover art field for the PlayerView background.
/// The image is blurred and desaturated so it recedes completely behind content.
private struct PlayerBackgroundModifier: ViewModifier {
    let image: UIImage?

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    // Warm-dark fallback
                    Rectangle()
                        .fill(Color(UIColor.systemBackground))

                    if let image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .scaleEffect(1.1)
                            .blur(radius: 70)
                            .saturation(0.35)
                            .opacity(0.55)
                            .clipped()
                    }

                    // Warm-glass scrim: pulls everything toward a neutral warm tone
                    Rectangle().fill(.ultraThinMaterial)
                    Rectangle().fill(DS.Color.coralAmbient)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// Renders an ambient blurred cover art field as the view's background.
    /// Pass `nil` to show a clean system-background fallback.
    func playerBackground(image: UIImage?) -> some View {
        modifier(PlayerBackgroundModifier(image: image))
    }
}

// MARK: - Artwork Subtitles Overlay

/// Frosted scrim that sits on cover art so subtitle text stays readable.
private struct ArtworkSubtitlesScrimModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: DS.Radius.coverArt, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: DS.Radius.coverArt, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.15),
                                    Color.black.opacity(0.45),
                                    Color.black.opacity(0.55),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
    }
}

extension View {
    /// Glass scrim for subtitle content layered on cover art.
    func artworkSubtitlesScrim() -> some View {
        modifier(ArtworkSubtitlesScrimModifier())
    }
}

// MARK: - Sheet Glass Background

/// Used as the background of half / full sheets (chapters, bookmarks, merge).
/// Slightly warmer than plain system material.
private struct SheetGlassModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Rectangle().fill(.thickMaterial)
                    Rectangle().fill(DS.Color.coralAmbient)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    /// Applies a warm thick-material background suitable for sheets.
    func sheetGlass() -> some View {
        modifier(SheetGlassModifier())
    }
}

// MARK: - Mini Player Pill

/// Floating liquid-glass oblong that backs the mini player.
///
/// The capsule is frosted (`ultraThinMaterial`) and receives a very faint tint
/// derived from the current artwork's average colour so the pill feels
/// contextually connected to what's playing. A thin coral progress strip runs
/// along the bottom inside edge, clipped to the capsule silhouette.
struct MiniPlayerPillBackground: View {
    /// Playback progress 0…1 for the bottom progress strip.
    let progress: Double
    /// Average colour extracted from the book's cover art. Falls back to coral.
    let tintColor: Color?

    private var effectiveTint: Color { tintColor ?? DS.Color.coral }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Frosted glass base — all layers clipped together to the capsule silhouette
            ZStack(alignment: .bottom) {
                Rectangle().fill(.ultraThinMaterial)

                // Artwork-derived tint: very transparent so it just warms the surface
                Rectangle().fill(effectiveTint.opacity(0.09))

                // Progress strip at the bottom edge
                GeometryReader { geo in
                    effectiveTint.opacity(0.70)
                        .frame(width: geo.size.width * CGFloat(min(progress, 1.0)))
                        .animation(DS.Animation.fade, value: progress)
                }
                .frame(height: 3)
            }
            .clipShape(Capsule(style: .continuous))

            // Hair-line stroke that traces the pill edge — gives it crispness
            Capsule(style: .continuous)
                .strokeBorder(.white.opacity(0.20), lineWidth: 0.5)
        }
        .applyShadows(DS.Shadow.card)
    }
}

// MARK: - UIImage average colour helper

private extension UIImage {
    /// Returns the perceptual average colour of the image as a SwiftUI `Color`.
    /// Uses `CIAreaAverage` for a single-pass GPU reduction — fast even on large images.
    var averageColor: Color? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let params: [String: Any] = [
            kCIInputImageKey: ciImage,
            kCIInputExtentKey: CIVector(cgRect: ciImage.extent)
        ]
        guard let filter = CIFilter(name: "CIAreaAverage", parameters: params),
              let output = filter.outputImage else { return nil }
        var bitmap = [UInt8](repeating: 0, count: 4)
        CIContext().render(
            output,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )
        return Color(
            red:   Double(bitmap[0]) / 255,
            green: Double(bitmap[1]) / 255,
            blue:  Double(bitmap[2]) / 255
        )
    }
}

extension UIImage {
    /// Public surface for extracting a SwiftUI `Color` tint from cover art.
    /// Backed by `CIAreaAverage` — see the private implementation above.
    var miniPlayerTint: Color? { averageColor }
}

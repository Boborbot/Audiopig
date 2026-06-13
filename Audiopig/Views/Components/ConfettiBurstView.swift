//
//  ConfettiBurstView.swift
//  Audiopig
//

import SwiftUI
import UIKit

// MARK: - Emitter Host

final class ConfettiEmitterUIView: UIView {

    private var didStart = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        clipsToBounds = false
    }

    required init?(coder: NSCoder) { fatalError() }

    func startBurst(onComplete: @escaping () -> Void) {
        guard !didStart else { return }
        didStart = true

        // Three emitters: top rain + two bottom-corner party cannons.
        let rain     = makeRainEmitter()
        let leftPop  = makeCannonEmitter(fromRight: false)
        let rightPop = makeCannonEmitter(fromRight: true)

        [rain, leftPop, rightPop].forEach { layer.addSublayer($0) }

        // Stop emitting after 0.5 s; particles coast / fall until ~2 s.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            for case let emitter as CAEmitterLayer in self.layer.sublayers ?? [] {
                emitter.birthRate = 0
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
            onComplete()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard let sublayers = layer.sublayers else { return }
        for (i, sub) in sublayers.enumerated() {
            guard let emitter = sub as? CAEmitterLayer else { continue }
            switch i {
            case 0: // rain — full top edge
                emitter.emitterPosition = CGPoint(x: bounds.midX, y: -8)
                emitter.emitterSize     = CGSize(width: bounds.width, height: 1)
            case 1: // left cannon — bottom-left corner
                emitter.emitterPosition = CGPoint(x: 0, y: bounds.maxY + 8)
            case 2: // right cannon — bottom-right corner
                emitter.emitterPosition = CGPoint(x: bounds.maxX, y: bounds.maxY + 8)
            default: break
            }
        }
    }

    // MARK: - Emitter builders

    private func makeRainEmitter() -> CAEmitterLayer {
        let e = CAEmitterLayer()
        e.emitterShape  = .line
        e.renderMode    = .unordered
        e.emitterCells  = allColors().flatMap { color in
            [makeCell(shape: squareImage(7), color: color, birthRate: 5,
                      velocity: 320, velocityRange: 130, spread: .pi / 2.0,
                      longitude: -.pi / 2, gravity: 460, spin: 4.0),
             makeCell(shape: circleImage(5), color: color, birthRate: 3,
                      velocity: 260, velocityRange: 100, spread: .pi / 2.2,
                      longitude: -.pi / 2, gravity: 400, spin: 0),
             makeCell(shape: ribbonImage(), color: color, birthRate: 2,
                      velocity: 300, velocityRange: 110, spread: .pi / 1.9,
                      longitude: -.pi / 2, gravity: 430, spin: 5.5)]
        }
        return e
    }

    private func makeCannonEmitter(fromRight: Bool) -> CAEmitterLayer {
        let e = CAEmitterLayer()
        e.emitterShape  = .point
        e.renderMode    = .unordered
        // Shoot diagonally inward and upward.
        let direction: CGFloat = fromRight ? -.pi * 0.72 : -.pi * 0.28
        e.emitterCells = allColors().flatMap { color in
            [makeCell(shape: squareImage(6), color: color, birthRate: 8,
                      velocity: 480, velocityRange: 160, spread: .pi / 3.5,
                      longitude: direction, gravity: 520, spin: 5.0),
             makeCell(shape: starImage(8), color: color, birthRate: 4,
                      velocity: 420, velocityRange: 140, spread: .pi / 4.0,
                      longitude: direction, gravity: 480, spin: 3.0),
             makeCell(shape: ribbonImage(), color: color, birthRate: 3,
                      velocity: 400, velocityRange: 120, spread: .pi / 3.0,
                      longitude: direction, gravity: 500, spin: 6.0)]
        }
        return e
    }

    // MARK: - Cell factory

    private func makeCell(
        shape: UIImage,
        color: UIColor,
        birthRate: Float,
        velocity: CGFloat,
        velocityRange: CGFloat,
        spread: CGFloat,
        longitude: CGFloat,
        gravity: CGFloat,
        spin: CGFloat
    ) -> CAEmitterCell {
        let cell = CAEmitterCell()
        cell.contents      = shape.cgImage
        cell.color         = color.cgColor
        cell.birthRate     = birthRate
        cell.lifetime      = Float.random(in: 1.1...1.6)
        cell.lifetimeRange = 0.35
        cell.velocity      = velocity + CGFloat.random(in: -20...20)
        cell.velocityRange = velocityRange
        cell.emissionLongitude = longitude
        cell.emissionRange     = spread
        cell.xAcceleration     = CGFloat.random(in: -40...40)
        cell.yAcceleration     = gravity
        cell.spin              = spin
        cell.spinRange         = spin * 0.6
        cell.scale             = CGFloat.random(in: 0.7...1.2)
        cell.scaleRange        = 0.3
        cell.alphaSpeed        = -0.55
        return cell
    }

    // MARK: - Palette (6 colours, 2 opacities each = 12 variants)

    private func allColors() -> [UIColor] {
        let base: [(CGFloat, CGFloat, CGFloat)] = [
            (0xF1, 0x84, 0x70),   // coral — brand
            (0xF7, 0xC8, 0x56),   // warm gold
            (0xFF, 0x9F, 0x7A),   // soft peach
            (0xDD, 0xD3, 0xC5),   // warm cream
            (0xA8, 0xD8, 0xBA),   // sage mint
            (1.0 * 255, 1.0 * 255, 1.0 * 255), // white
        ]
        return base.flatMap { r, g, b -> [UIColor] in
            let full  = UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 1.0)
            let muted = UIColor(red: r / 255, green: g / 255, blue: b / 255, alpha: 0.65)
            return [full, muted]
        }
    }

    // MARK: - Shape bitmaps

    private func squareImage(_ size: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: .init(width: size, height: size)).image { ctx in
            UIColor.white.setFill()
            // slight rounded corner for a softer feel
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero,
                                                         size: CGSize(width: size, height: size)),
                                    cornerRadius: size * 0.15)
            path.fill()
        }
    }

    private func circleImage(_ size: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: .init(width: size, height: size)).image { ctx in
            UIColor.white.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero,
                                                  size: CGSize(width: size, height: size)))
        }
    }

    /// Thin ribbon / streamer shape.
    private func ribbonImage() -> UIImage {
        let w: CGFloat = 3, h: CGFloat = 10
        return UIGraphicsImageRenderer(size: .init(width: w, height: h)).image { ctx in
            UIColor.white.setFill()
            let path = UIBezierPath(roundedRect: CGRect(origin: .zero,
                                                         size: CGSize(width: w, height: h)),
                                    cornerRadius: 1)
            path.fill()
        }
    }

    /// 5-pointed star.
    private func starImage(_ size: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: .init(width: size, height: size)).image { ctx in
            UIColor.white.setFill()
            let path = UIBezierPath()
            let center = CGPoint(x: size / 2, y: size / 2)
            let outerR = size / 2
            let innerR = size / 4.5
            let points = 5
            for i in 0..<(points * 2) {
                let angle = (.pi / CGFloat(points)) * CGFloat(i) - .pi / 2
                let r: CGFloat = i.isMultiple(of: 2) ? outerR : innerR
                let pt = CGPoint(x: center.x + r * cos(angle),
                                 y: center.y + r * sin(angle))
                i == 0 ? path.move(to: pt) : path.addLine(to: pt)
            }
            path.close()
            path.fill()
        }
    }
}

// MARK: - SwiftUI Wrapper

struct ConfettiBurstView: UIViewRepresentable {
    let onComplete: () -> Void

    func makeUIView(context: Context) -> ConfettiEmitterUIView {
        ConfettiEmitterUIView()
    }

    func updateUIView(_ uiView: ConfettiEmitterUIView, context: Context) {
        uiView.startBurst(onComplete: onComplete)
    }
}
